import ContextCoreKit
import Foundation
import Testing

@testable import DaylineProductKit

private struct DailySummaryGeneratorFake: DailySummaryGenerating {
  let result: Result<SemanticArtifactDocument, DailySummaryFailure>

  func generate(
    for _: Date,
    timezone _: TimeZone,
    language _: String
  ) async throws -> SemanticArtifactDocument {
    try result.get()
  }
}

@MainActor
@Test
func publishesAReadyDailySummary() async {
  let artifact = dailyArtifact()
  let model = DailySummaryModel(
    generator: DailySummaryGeneratorFake(result: .success(artifact))
  )

  await model.generate()

  #expect(model.state == .ready)
  #expect(model.summary == artifact)
}

@MainActor
@Test
func exposesContentFreeEmptyAndUnavailableStates() async {
  let empty = DailySummaryModel(
    generator: DailySummaryGeneratorFake(result: .failure(.emptyContext))
  )
  let unavailable = DailySummaryModel(
    generator: DailySummaryGeneratorFake(result: .failure(.generationUnavailable))
  )

  await empty.generate()
  await unavailable.generate()

  #expect(empty.state == .empty)
  #expect(unavailable.state == .intelligenceUnavailable)
}

private func dailyArtifact() -> SemanticArtifactDocument {
  SemanticArtifactDocument(
    id: "018f6ea2-8f44-7f00-8000-000000000912",
    createdAt: "2026-09-14T12:00:00Z",
    dayId: DayIDDocument(localDate: "2026-09-14", timezone: "Asia/Tokyo"),
    sessionId: nil,
    kind: "summary",
    content: SemanticContentDocument(text: "一日の要約", attributes: ["language": "ja"]),
    sourceEventIds: ["018f6ea2-8f44-7f00-8000-000000000901"],
    sourceArtifactIds: [],
    confidence: nil,
    sensitivity: .sensitive,
    retention: RetentionDocument(type: "days", days: 30),
    generation: GenerationProvenanceDocument(
      runtime: "stub",
      model: "deterministic-stub",
      promptId: "daily-summary",
      promptVersion: 1,
      runId: "018f6ea2-8f44-7f00-8000-000000000913",
      generatedAt: "2026-09-14T12:00:00Z"
    )
  )
}
