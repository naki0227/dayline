import Foundation
import Testing

@testable import ContextCaptureKit

@MainActor
private final class RecorderFake: AudioRecording {
  var startResult: Result<URL, CaptureFailure>
  private(set) var startCount = 0
  private(set) var stopCount = 0
  private var interruptionHandler: (@MainActor @Sendable (AudioInterruption) async -> Void)?

  init(startResult: Result<URL, CaptureFailure> = .success(URL(filePath: "/tmp/dayline.m4a"))) {
    self.startResult = startResult
  }

  func startChunk() async throws -> URL {
    startCount += 1
    return try startResult.get()
  }

  func stopChunk() async {
    stopCount += 1
  }

  func setInterruptionHandler(
    _ handler: @escaping @MainActor @Sendable (AudioInterruption) async -> Void
  ) {
    interruptionHandler = handler
  }

  func emit(_ interruption: AudioInterruption) async {
    await interruptionHandler?(interruption)
  }
}

private struct TranscriberFake: SpeechTranscribing {
  let output: Result<[TranscriptionSegment], TranscriptionFailure>

  func segments(
    for _: URL,
    locale _: Locale
  ) async throws -> AsyncThrowingStream<TranscriptionSegment, Error> {
    let values = try output.get()
    return AsyncThrowingStream { continuation in
      for value in values {
        continuation.yield(value)
      }
      continuation.finish()
    }
  }
}

@MainActor
@Test
func startsAndStopsDailyCapture() async {
  let recorder = RecorderFake()
  let startedAt = Date(timeIntervalSince1970: 10)
  let coordinator = CaptureCoordinator(
    recorder: recorder,
    now: { startedAt },
    automaticChunkDuration: nil
  )

  await coordinator.start()
  #expect(coordinator.dailyState == .running)
  #expect(coordinator.audioState == .recording)
  #expect(coordinator.startedAt == startedAt)

  await coordinator.stop()
  #expect(coordinator.dailyState == .stopped)
  #expect(coordinator.audioState == .stopped)
  #expect(recorder.stopCount == 1)
}

@MainActor
@Test
func interruptionDoesNotEndOneDayCapture() async {
  let recorder = RecorderFake()
  let coordinator = CaptureCoordinator(recorder: recorder, automaticChunkDuration: nil)
  await coordinator.start()

  await coordinator.interruptionBegan()
  #expect(coordinator.dailyState == .running)
  #expect(coordinator.audioState == .interrupted)

  await coordinator.interruptionEnded(shouldResume: true)
  #expect(coordinator.dailyState == .running)
  #expect(coordinator.audioState == .recording)
  #expect(recorder.startCount == 2)
}

@MainActor
@Test
func recorderInterruptionEventsDriveTheCoordinator() async {
  let recorder = RecorderFake()
  let coordinator = CaptureCoordinator(recorder: recorder, automaticChunkDuration: nil)
  await coordinator.start()

  await recorder.emit(.began)
  #expect(coordinator.snapshot.daily == .running)
  #expect(coordinator.snapshot.audio == .interrupted)

  await recorder.emit(.ended(shouldResume: true))
  #expect(coordinator.snapshot.audio == .recording)
}

@MainActor
@Test
func startFailureIsContentFreeAndRecoverable() async {
  let recorder = RecorderFake(startResult: .failure(.microphonePermissionDenied))
  let coordinator = CaptureCoordinator(recorder: recorder, automaticChunkDuration: nil)

  await coordinator.start()
  #expect(coordinator.dailyState == .stopped)
  #expect(coordinator.audioState == .unavailable)
  #expect(coordinator.lastFailure == .microphonePermissionDenied)
}

@MainActor
@Test
func rotatesChunksWithoutChangingDailyState() async {
  let recorder = RecorderFake()
  let coordinator = CaptureCoordinator(recorder: recorder, automaticChunkDuration: nil)
  await coordinator.start()

  await coordinator.rotateChunk()
  #expect(coordinator.dailyState == .running)
  #expect(coordinator.audioState == .recording)
  #expect(recorder.startCount == 2)
  #expect(recorder.stopCount == 1)
}

@MainActor
@Test
func completedChunkPublishesOnlyFinalizedTranscriptEvidence() async {
  let draft = TranscriptionSegment(
    text: "draft",
    localeIdentifier: "ja-JP",
    startTime: 0,
    duration: 1,
    isFinal: false
  )
  let final = TranscriptionSegment(
    text: "final",
    localeIdentifier: "ja-JP",
    startTime: 0,
    duration: 1,
    isFinal: true
  )
  let coordinator = CaptureCoordinator(
    recorder: RecorderFake(),
    transcriber: TranscriberFake(output: .success([draft, final])),
    automaticChunkDuration: nil
  )

  await coordinator.processCompletedChunk(URL(filePath: "/tmp/chunk.m4a"))
  #expect(coordinator.transcript.volatile == nil)
  #expect(coordinator.transcript.finalized == [final])
}

@MainActor
@Test
func transcriptionFailureDoesNotStopDailyCapture() async {
  let coordinator = CaptureCoordinator(
    recorder: RecorderFake(),
    transcriber: TranscriberFake(output: .failure(.assetsUnavailable)),
    automaticChunkDuration: nil
  )
  await coordinator.start()

  await coordinator.processCompletedChunk(URL(filePath: "/tmp/chunk.m4a"))
  #expect(coordinator.dailyState == .running)
  #expect(coordinator.lastTranscriptionFailure == .assetsUnavailable)
}
