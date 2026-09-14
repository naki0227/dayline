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

  private let recorder: any AudioRecording
  private let transcriber: (any SpeechTranscribing)?
  private let transcriptionLocale: Locale
  private let now: @MainActor @Sendable () -> Date
  private let automaticChunkDuration: Duration?
  private var rotationTask: Task<Void, Never>?

  public init(
    recorder: any AudioRecording,
    transcriber: (any SpeechTranscribing)? = nil,
    transcriptionLocale: Locale = Locale(identifier: "ja-JP"),
    now: @escaping @MainActor @Sendable () -> Date = Date.init,
    automaticChunkDuration: Duration? = .seconds(300)
  ) {
    self.recorder = recorder
    self.transcriber = transcriber
    self.transcriptionLocale = transcriptionLocale
    self.now = now
    self.automaticChunkDuration = automaticChunkDuration
    recorder.setInterruptionHandler { [weak self] interruption in
      switch interruption {
      case .began:
        await self?.interruptionBegan()
      case .ended(let shouldResume):
        await self?.interruptionEnded(shouldResume: shouldResume)
      }
    }
  }

  public var snapshot: CaptureSnapshot {
    CaptureSnapshot(
      daily: dailyState,
      audio: audioState,
      activeFileURL: activeFileURL,
      startedAt: startedAt,
      lastFailure: lastFailure
    )
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
      failStart(with: failure)
    } catch {
      failStart(with: .recordingFailed)
    }
  }

  public func stop() async {
    guard dailyState == .running else { return }
    dailyState = .stopping
    rotationTask?.cancel()
    rotationTask = nil
    let completedChunk = activeFileURL
    await recorder.stopChunk()
    dailyState = .stopped
    audioState = .stopped
    activeFileURL = nil
    startedAt = nil
    scheduleTranscription(for: completedChunk)
  }

  public func rotateChunk() async {
    guard dailyState == .running, audioState == .recording else { return }
    let completedChunk = activeFileURL
    await recorder.stopChunk()
    scheduleTranscription(for: completedChunk)
    do {
      activeFileURL = try await recorder.startChunk()
    } catch let failure as CaptureFailure {
      audioState = .unavailable
      activeFileURL = nil
      lastFailure = failure
    } catch {
      audioState = .unavailable
      activeFileURL = nil
      lastFailure = .recordingFailed
    }
  }

  public func interruptionBegan() async {
    guard dailyState == .running else { return }
    let completedChunk = activeFileURL
    await recorder.stopChunk()
    audioState = .interrupted
    activeFileURL = nil
    scheduleTranscription(for: completedChunk)
  }

  public func interruptionEnded(shouldResume: Bool) async {
    guard dailyState == .running, audioState == .interrupted, shouldResume else { return }
    do {
      activeFileURL = try await recorder.startChunk()
      audioState = .recording
    } catch let failure as CaptureFailure {
      audioState = .unavailable
      lastFailure = failure
    } catch {
      audioState = .unavailable
      lastFailure = .recordingFailed
    }
  }

  private func failStart(with failure: CaptureFailure) {
    dailyState = .stopped
    audioState = .unavailable
    activeFileURL = nil
    startedAt = nil
    lastFailure = failure
  }

  public func processCompletedChunk(_ fileURL: URL) async {
    guard let transcriber else { return }
    do {
      let segments = try await transcriber.segments(
        for: fileURL,
        locale: transcriptionLocale
      )
      for try await segment in segments {
        transcript.ingest(segment)
      }
      lastTranscriptionFailure = nil
    } catch let failure as TranscriptionFailure {
      lastTranscriptionFailure = failure
    } catch {
      lastTranscriptionFailure = .analysisFailed
    }
  }

  private func scheduleTranscription(for fileURL: URL?) {
    guard let fileURL, transcriber != nil else { return }
    Task { [weak self] in
      await self?.processCompletedChunk(fileURL)
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
}
