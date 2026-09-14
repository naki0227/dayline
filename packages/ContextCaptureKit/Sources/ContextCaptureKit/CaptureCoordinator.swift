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

  private let recorder: any AudioRecording
  private let now: @MainActor @Sendable () -> Date
  private let automaticChunkDuration: Duration?
  private var rotationTask: Task<Void, Never>?

  public init(
    recorder: any AudioRecording,
    now: @escaping @MainActor @Sendable () -> Date = Date.init,
    automaticChunkDuration: Duration? = .seconds(300)
  ) {
    self.recorder = recorder
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
    await recorder.stopChunk()
    dailyState = .stopped
    audioState = .stopped
    activeFileURL = nil
    startedAt = nil
  }

  public func rotateChunk() async {
    guard dailyState == .running, audioState == .recording else { return }
    await recorder.stopChunk()
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
    await recorder.stopChunk()
    audioState = .interrupted
    activeFileURL = nil
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
