import AppleIntelligenceKit
import ContextCoreKit
import Testing

@testable import DaylineProductKit

@Test
func presentsOnlyNonEmptyStructuredSectionsWithProvenanceCount() throws {
  let artifact = try presentationArtifact(
    attributes: SemanticSectionsCodec.attributes(
      for: SemanticSections(
        summary: "Summary",
        highlights: ["Highlight"],
        topics: [],
        decisions: ["Decision"],
        todos: ["TODO"],
        ideas: [],
        questions: ["Question"]
      ),
      language: "en"
    )
  )

  let presentation = ArtifactPresentation(artifact: artifact)

  #expect(presentation.isStructured)
  #expect(presentation.summary == "Summary")
  #expect(presentation.sections.map(\.kind) == [.highlights, .decisions, .todos, .questions])
  #expect(presentation.sourceCount == 2)
}

@Test
func legacyArtifactFallsBackToSummaryWithoutFailingPresentation() {
  let artifact = presentationArtifact(attributes: ["language": "ja"])

  let presentation = ArtifactPresentation(artifact: artifact)

  #expect(!presentation.isStructured)
  #expect(presentation.summary == "Summary")
  #expect(presentation.sections.isEmpty)
}

private func presentationArtifact(
  attributes: [String: String]
) -> SemanticArtifactDocument {
  SemanticArtifactDocument(
    id: "018f6ea2-8f44-7f00-8000-000000000931",
    createdAt: "2026-09-15T01:00:00Z",
    dayId: DayIDDocument(localDate: "2026-09-15", timezone: "Asia/Tokyo"),
    sessionId: nil,
    kind: "summary",
    content: SemanticContentDocument(text: "Summary", attributes: attributes),
    sourceEventIds: ["018f6ea2-8f44-7f00-8000-000000000932"],
    sourceArtifactIds: ["018f6ea2-8f44-7f00-8000-000000000933"],
    confidence: nil,
    sensitivity: .sensitive,
    retention: RetentionDocument(type: "days", days: 30),
    generation: GenerationProvenanceDocument(
      runtime: "stub",
      model: "deterministic-stub",
      promptId: "daily-summary",
      promptVersion: 1,
      runId: "018f6ea2-8f44-7f00-8000-000000000934",
      generatedAt: "2026-09-15T01:00:00Z"
    )
  )
}
