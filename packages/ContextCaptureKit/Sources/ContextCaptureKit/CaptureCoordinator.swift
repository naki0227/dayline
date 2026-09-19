import Foundation
import Observation

@MainActor
@Observable
public final class CaptureCoordinator {
  public private(set) var dailyState: DailyCaptureState = .stopped
  public private(set) var audioState: AudioSourceState = .stopped
  public private(set) var activeFileURL: URL?
  public private(set) var startedAt: Date?
  public private(set) var lastFailure: CaptureFailure?
  public private(set) var transcript = TranscriptBuffer()
  public private(set) var lastTranscriptionFailure: TranscriptionFailure?
  public private(set) var persistedTranscriptEventCount = 0
  public private(set) var lastTranscriptEventFailure: TranscriptEventPipelineFailure?

  private let recorder: any AudioRecording
  private let transcriber: (any SpeechTranscribing)?
  private let transcriptEventPipeline: TranscriptEventPipeline?
  private let transcriptionLocale: Locale
  private let now: @MainActor @Sendable () -> Date
  private let automaticChunkDuration: Duration?
  private let audioRecoveryInterval: Duration?
  private var rotationTask: Task<Void, Never>?
  private var audioRecoveryTask: Task<Void, Never>?

  public init(
    recorder: any AudioRecording,
    transcriber: (any SpeechTranscribing)? = nil,
    transcriptEventPipeline: TranscriptEventPipeline? = nil,
    transcriptionLocale: Locale = Locale(identifier: "ja-JP"),
    now: @escaping @MainActor @Sendable () -> Date = Date.init,
    automaticChunkDuration: Duration? = .seconds(300),
    audioRecoveryInterval: Duration? = .seconds(2)
  ) {
    self.recorder = recorder
    self.transcriber = transcriber
    self.transcriptEventPipeline = transcriptEventPipeline
    self.transcriptionLocale = transcriptionLocale
    self.now = now
    self.automaticChunkDuration = automaticChunkDuration
    self.audioRecoveryInterval = audioRecoveryInterval
    recorder.setInterruptionHandler { [weak self] interruption in
      switch interruption {
      case .began:
        await self?.interruptionBegan()
      case .ended(let shouldResume):
        await self?.interruptionEnded(shouldResume: shouldResume)
      }
    }
  }

  public func toggle() async {
    switch dailyState {
    case .stopped:
      await start()
    case .running:
      await stop()
    case .starting, .stopping:
      break
    }
  }

  public func start() async {
    guard dailyState == .stopped else { return }
    dailyState = .starting
    lastFailure = nil
    do {
      activeFileURL = try await recorder.startChunk()
      startedAt = now()
      dailyState = .running
      audioState = .recording
      scheduleRotation()
    } catch let failure as CaptureFailure {
      if failure == .audioTemporarilyUnavailable {
        enterAudioWaitingState()
      } else {
        failStart(with: failure)
      }
    } catch {
      failStart(with: .recordingFailed)
    }
  }

  public func stop() async {
    guard dailyState == .running else { return }
    dailyState = .stopping
    rotationTask?.cancel()
    rotationTask = nil
    audioRecoveryTask?.cancel()
    audioRecoveryTask = nil
    let completedChunk = activeFileURL
    let completedChunkStartedAt = startedAt
    await recorder.stopChunk()
    dailyState = .stopped
    audioState = .stopped
    activeFileURL = nil
    startedAt = nil
    scheduleTranscription(for: completedChunk, startedAt: completedChunkStartedAt)
  }

  public func rotateChunk() async {
    guard dailyState == .running, audioState == .recording else { return }
    let completedChunk = activeFileURL
    let completedChunkStartedAt = startedAt
    await recorder.stopChunk()
    scheduleTranscription(for: completedChunk, startedAt: completedChunkStartedAt)
    do {
      activeFileURL = try await recorder.startChunk()
      startedAt = now()
    } catch let failure as CaptureFailure {
      rotationTask?.cancel()
      rotationTask = nil
      handleAudioStartFailure(failure)
    } catch {
      rotationTask?.cancel()
      rotationTask = nil
      handleAudioStartFailure(.recordingFailed)
    }
  }

  public func interruptionBegan() async {
    guard dailyState == .running else { return }
    rotationTask?.cancel()
    rotationTask = nil
    audioRecoveryTask?.cancel()
    audioRecoveryTask = nil
    let completedChunk = activeFileURL
    let completedChunkStartedAt = startedAt
    await recorder.stopChunk()
    audioState = .interrupted
    activeFileURL = nil
    startedAt = nil
    scheduleTranscription(for: completedChunk, startedAt: completedChunkStartedAt)
  }

  public func interruptionEnded(shouldResume: Bool) async {
    guard
      dailyState == .running,
      audioState == .interrupted || audioState == .waitingForAudio
    else { return }
    audioState = .waitingForAudio
    if !shouldResume {
      scheduleAudioRecovery()
      return
    }
    await retryWaitingAudio()
  }

  public func retryWaitingAudio() async {
    guard dailyState == .running, audioState == .waitingForAudio else { return }
    do {
      activeFileURL = try await recorder.startChunk()
      startedAt = now()
      audioState = .recording
      lastFailure = nil
      audioRecoveryTask?.cancel()
      audioRecoveryTask = nil
      scheduleRotation()
    } catch let failure as CaptureFailure {
      handleAudioStartFailure(failure)
    } catch {
      handleAudioStartFailure(.recordingFailed)
    }
  }

  private func failStart(with failure: CaptureFailure) {
    dailyState = .stopped
    audioState = .unavailable
    activeFileURL = nil
    startedAt = nil
    lastFailure = failure
  }

  private func enterAudioWaitingState() {
    dailyState = .running
    audioState = .waitingForAudio
    activeFileURL = nil
    startedAt = nil
    lastFailure = nil
    scheduleAudioRecovery()
  }

  private func handleAudioStartFailure(_ failure: CaptureFailure) {
    activeFileURL = nil
    startedAt = nil
    if failure == .audioTemporarilyUnavailable {
      audioState = .waitingForAudio
      lastFailure = nil
      scheduleAudioRecovery()
    } else {
      audioState = .unavailable
      lastFailure = failure
      audioRecoveryTask?.cancel()
      audioRecoveryTask = nil
    }
  }
}

extension CaptureCoordinator {
  public func processCompletedChunk(
    _ fileURL: URL,
    startedAt chunkStartedAt: Date
  ) async {
    guard let transcriber else { return }
    do {
      let segments = try await transcriber.segments(
        for: fileURL,
        locale: transcriptionLocale
      )
      for try await segment in segments {
        guard transcript.ingest(segment, sourceID: fileURL.lastPathComponent) else { continue }
        await persist(segment, chunkStartedAt: chunkStartedAt)
      }
      lastTranscriptionFailure = nil
    } catch let failure as TranscriptionFailure {
      lastTranscriptionFailure = failure
    } catch {
      lastTranscriptionFailure = .analysisFailed
    }
  }

  private func persist(
    _ segment: TranscriptionSegment,
    chunkStartedAt: Date
  ) async {
    guard let transcriptEventPipeline else { return }
    do {
      _ = try await transcriptEventPipeline.process(
        segment,
        chunkStartedAt: chunkStartedAt
      )
      persistedTranscriptEventCount += 1
      lastTranscriptEventFailure = nil
    } catch let failure as TranscriptEventPipelineFailure {
      lastTranscriptEventFailure = failure
    } catch {
      lastTranscriptEventFailure = .persistenceFailed
    }
  }

  private func scheduleTranscription(for fileURL: URL?, startedAt: Date?) {
    guard let fileURL, let startedAt, transcriber != nil else { return }
    Task { [weak self] in
      await self?.processCompletedChunk(fileURL, startedAt: startedAt)
    }
  }

  private func scheduleRotation() {
    guard let automaticChunkDuration else { return }
    rotationTask?.cancel()
    rotationTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: automaticChunkDuration)
        } catch {
          return
        }
        guard let self, self.dailyState == .running else { return }
        await self.rotateChunk()
      }
    }
  }

  private func scheduleAudioRecovery() {
    guard let audioRecoveryInterval, audioRecoveryTask == nil else { return }
    audioRecoveryTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: audioRecoveryInterval)
        } catch {
          return
        }
        guard
          let self,
          self.dailyState == .running,
          self.audioState == .waitingForAudio
        else { return }
        await self.retryWaitingAudio()
      }
    }
  }
}
