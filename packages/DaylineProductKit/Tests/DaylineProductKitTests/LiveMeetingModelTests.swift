import ContextCoreKit
import Foundation
import Testing

@testable import DaylineProductKit

@MainActor
@Test
func liveMeetingSchedulesProfileIntervalAndPublishesState() async {
  let sleeper = SleepProbe()
  let artifact = liveArtifact()
  let model = LiveMeetingModel(
    generator: LiveMeetingGeneratorFake(result: .success(artifact)),
    sleep: { duration in try await sleeper.recordAndCancel(duration) }
  )

  model.begin(
    sessionID: "018f6ea2-8f44-7f00-8000-000000000920",
    startedAt: Date(timeIntervalSince1970: 1_789_320_600)
  )
  await eventually { await sleeper.durations.count == 1 }
  await model.refresh()

  #expect(await sleeper.durations == [.seconds(30)])
  #expect(model.state == .ready)
  #expect(model.latest == artifact)
}

@MainActor
@Test
func liveMeetingExposesEmptyAndUnavailableStates() async {
  let empty = LiveMeetingModel(
    generator: LiveMeetingGeneratorFake(result: .failure(.emptyContext))
  )
  let unavailable = LiveMeetingModel(
    generator: LiveMeetingGeneratorFake(result: .failure(.generationUnavailable))
  )
  let sessionID = "018f6ea2-8f44-7f00-8000-000000000920"
  let startedAt = Date(timeIntervalSince1970: 1_789_320_600)

  empty.begin(sessionID: sessionID, startedAt: startedAt)
  unavailable.begin(sessionID: sessionID, startedAt: startedAt)
  await empty.refresh()
  await unavailable.refresh()

  #expect(empty.state == .empty)
  #expect(unavailable.state == .intelligenceUnavailable)
}

private struct LiveMeetingGeneratorFake: LiveMeetingGenerating {
  let updateIntervalSeconds: UInt16 = 30
  let result: Result<SemanticArtifactDocument, LiveMeetingFailure>

  func generate(
    sessionID _: String,
    startedAt _: Date,
    timezone _: TimeZone,
    language _: String
  ) async throws -> SemanticArtifactDocument {
    try result.get()
  }
}

private actor SleepProbe {
  private(set) var durations: [Duration] = []

  func recordAndCancel(_ duration: Duration) throws {
    durations.append(duration)
    throw CancellationError()
  }
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

private func liveArtifact() -> SemanticArtifactDocument {
  SemanticArtifactDocument(
    id: "018f6ea2-8f44-7f00-8000-000000000922",
    createdAt: "2026-09-14T12:01:00Z",
    dayId: DayIDDocument(localDate: "2026-09-14", timezone: "Asia/Tokyo"),
    sessionId: "018f6ea2-8f44-7f00-8000-000000000920",
    kind: "summary",
    content: SemanticContentDocument(text: "会議の現在状態", attributes: ["language": "ja"]),
    sourceEventIds: ["018f6ea2-8f44-7f00-8000-000000000901"],
    sourceArtifactIds: [],
    confidence: nil,
    sensitivity: .sensitive,
    retention: RetentionDocument(type: "days", days: 30),
    generation: GenerationProvenanceDocument(
      runtime: "stub",
      model: "deterministic-stub",
      promptId: "live-meeting",
      promptVersion: 1,
      runId: "018f6ea2-8f44-7f00-8000-000000000923",
      generatedAt: "2026-09-14T12:01:00Z"
    )
  )
}
