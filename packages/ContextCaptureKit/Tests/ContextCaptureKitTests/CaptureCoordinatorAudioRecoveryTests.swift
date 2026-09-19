import Foundation
import Testing

@testable import ContextCaptureKit

@MainActor
private final class RecoveryRecorderFake: AudioRecording {
  var startResult: Result<URL, CaptureFailure>
  private(set) var startCount = 0

  init(startResult: Result<URL, CaptureFailure> = .success(URL(filePath: "/tmp/dayline.m4a"))) {
    self.startResult = startResult
  }

  func startChunk() async throws -> URL {
    startCount += 1
    return try startResult.get()
  }

  func stopChunk() async {}
}

@MainActor
@Test
func startingDuringACallKeepsDailyRunningWhileAudioWaits() async {
  let recorder = RecoveryRecorderFake(startResult: .failure(.audioTemporarilyUnavailable))
  let coordinator = CaptureCoordinator(
    recorder: recorder,
    automaticChunkDuration: nil,
    audioRecoveryInterval: nil
  )

  await coordinator.start()

  #expect(coordinator.dailyState == .running)
  #expect(coordinator.audioState == .waitingForAudio)
  #expect(coordinator.activeFileURL == nil)
  #expect(coordinator.lastFailure == nil)
}

@MainActor
@Test
func waitingAudioStartsAFreshChunkWhenItBecomesAvailable() async {
  let recorder = RecoveryRecorderFake(startResult: .failure(.audioTemporarilyUnavailable))
  let coordinator = CaptureCoordinator(
    recorder: recorder,
    automaticChunkDuration: nil,
    audioRecoveryInterval: nil
  )
  await coordinator.start()
  recorder.startResult = .success(URL(filePath: "/tmp/resumed-dayline.m4a"))

  await coordinator.retryWaitingAudio()

  #expect(coordinator.dailyState == .running)
  #expect(coordinator.audioState == .recording)
  #expect(coordinator.activeFileURL?.lastPathComponent == "resumed-dayline.m4a")
  #expect(recorder.startCount == 2)
}

@MainActor
@Test
func waitingAudioRetriesAutomatically() async throws {
  let recorder = RecoveryRecorderFake(startResult: .failure(.audioTemporarilyUnavailable))
  let coordinator = CaptureCoordinator(
    recorder: recorder,
    automaticChunkDuration: nil,
    audioRecoveryInterval: .milliseconds(1)
  )
  await coordinator.start()
  recorder.startResult = .success(URL(filePath: "/tmp/automatic-resume.m4a"))

  for _ in 0..<100 where coordinator.audioState != .recording {
    try await Task.sleep(for: .milliseconds(1))
  }

  #expect(coordinator.audioState == .recording)
  #expect(recorder.startCount >= 2)
}

@MainActor
@Test
func interruptionWithoutImmediateResumeMovesToAutomaticWaiting() async {
  let recorder = RecoveryRecorderFake()
  let coordinator = CaptureCoordinator(
    recorder: recorder,
    automaticChunkDuration: nil,
    audioRecoveryInterval: nil
  )
  await coordinator.start()
  await coordinator.interruptionBegan()

  await coordinator.interruptionEnded(shouldResume: false)

  #expect(coordinator.dailyState == .running)
  #expect(coordinator.audioState == .waitingForAudio)
  #expect(recorder.startCount == 1)
}
