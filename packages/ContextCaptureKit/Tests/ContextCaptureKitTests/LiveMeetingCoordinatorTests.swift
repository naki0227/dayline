import ContextCoreKit
import Foundation
import Testing

@testable import ContextCaptureKit

@MainActor
@Test
func liveMeetingSeparatesVolatileTextAndPersistsFinalEvidence() async throws {
  let speech = FakeLiveSpeechStream()
  let store = CapturingLiveEventStore()
  let candidate = TranscriptEventMapper(
    timezoneIdentifier: "Asia/Tokyo",
    deviceID: "test-device",
    eventID: { "018f6ea2-8f44-7f00-8000-000000000911" },
    now: { Date(timeIntervalSince1970: 1_789_320_620) }
  )
  let mapper = try #require(candidate)
  let coordinator = LiveMeetingCoordinator(
    speech: speech,
    eventPipeline: TranscriptEventPipeline(mapper: mapper, store: store),
    now: { Date(timeIntervalSince1970: 1_789_320_600) },
    makeSessionID: { "018f6ea2-8f44-7f00-8000-000000000910" }
  )

  await coordinator.start()
  speech.yield(segment(text: "draft", isFinal: false))
  await eventually { coordinator.transcript.volatile?.text == "draft" }

  #expect(coordinator.state == .running)
  #expect(coordinator.transcript.volatile?.text == "draft")
  #expect(await store.events.isEmpty)

  speech.yield(segment(text: "決定しました", isFinal: true))
  await eventually { coordinator.persistedEventCount == 1 }
  await coordinator.stop()

  let event = try #require(await store.events.first)
  #expect(event.sessionId == "018f6ea2-8f44-7f00-8000-000000000910")
  #expect(event.payload.content.text == "決定しました")
  #expect(coordinator.state == .stopped)
}

@MainActor
@Test
func liveMeetingMapsStartupAndStreamFailuresWithoutContent() async {
  let denied = FakeLiveSpeechStream(startFailure: .speechPermissionDenied)
  let deniedCoordinator = LiveMeetingCoordinator(speech: denied)

  await deniedCoordinator.start()

  #expect(deniedCoordinator.state == .unavailable)
  #expect(deniedCoordinator.lastTranscriptionFailure == .speechPermissionDenied)
  #expect(deniedCoordinator.sessionID == nil)

  let failing = FakeLiveSpeechStream()
  let failingCoordinator = LiveMeetingCoordinator(speech: failing)
  await failingCoordinator.start()
  failing.finish(throwing: TranscriptionFailure.analysisFailed)
  await eventually { failingCoordinator.state == .unavailable }

  #expect(failingCoordinator.lastTranscriptionFailure == .analysisFailed)
  #expect(failing.stopCount == 1)
}

private func segment(text: String, isFinal: Bool) -> TranscriptionSegment {
  TranscriptionSegment(
    text: text,
    localeIdentifier: "ja-JP",
    startTime: 2,
    duration: 1,
    isFinal: isFinal
  )
}

@MainActor
private func eventually(
  _ condition: @escaping @MainActor () async -> Bool
) async {
  for _ in 0..<100 {
    if await condition() { return }
    await Task.yield()
  }
}

@MainActor
private final class FakeLiveSpeechStream: LiveSpeechStreaming {
  private(set) var stopCount = 0
  private let startFailure: TranscriptionFailure?
  private var continuation: AsyncThrowingStream<TranscriptionSegment, Error>.Continuation?

  init(startFailure: TranscriptionFailure? = nil) {
    self.startFailure = startFailure
  }

  func start(
    locale _: Locale
  ) async throws -> AsyncThrowingStream<TranscriptionSegment, Error> {
    if let startFailure { throw startFailure }
    return AsyncThrowingStream { continuation in
      self.continuation = continuation
    }
  }

  func stop() async {
    stopCount += 1
    continuation?.finish()
  }

  func yield(_ segment: TranscriptionSegment) {
    continuation?.yield(segment)
  }

  func finish(throwing error: any Error) {
    continuation?.finish(throwing: error)
  }
}

private actor CapturingLiveEventStore: ContextEventPersisting {
  private(set) var events: [TextContextEventDocument] = []

  func persist(_ event: TextContextEventDocument) -> TextContextEventDocument {
    events.append(event)
    return event
  }
}
