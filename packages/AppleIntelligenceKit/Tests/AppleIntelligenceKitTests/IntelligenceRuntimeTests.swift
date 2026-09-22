import ContextCoreKit
import Foundation
import Testing

@testable import AppleIntelligenceKit

private struct RuntimeSpy: IntelligenceRuntime {
  func generate(
    request _: IntelligenceRequest,
    context _: ContextBundleDocument
  ) async throws -> SemanticArtifactDocument {
    throw StubIntelligenceRuntimeError.emptyContext
  }
}

@Test
func runtimeBoundaryAcceptsIndependentImplementations() {
  let runtime: any IntelligenceRuntime = RuntimeSpy()
  #expect(runtime is RuntimeSpy)
}

@Test
func appleRuntimeUsesSharedSystemAvailability() {
  let runtime = AppleFoundationModelRuntime(
    reducer: ContextReducer { context, _ in context }
  )

  #expect(runtime.availability() == SystemIntelligenceAvailability.current())
}

@Test
func stubMapsArtifactEvidenceAndSensitivity() async throws {
  let context = try fixtureBundle()
  let artifact = try await StubIntelligenceRuntime().generate(
    request: request(),
    context: context
  )

  #expect(artifact.sourceEventIds.isEmpty)
  #expect(artifact.sourceArtifactIds == [context.items[0].recordId])
  #expect(artifact.sensitivity == .sensitive)
  #expect(artifact.content.attributes["language"] == "en")
  let sections = try SemanticSectionsCodec.decode(from: artifact.content.attributes)
  #expect(sections.summary == artifact.content.text)
  #expect(sections.highlights == [context.items[0].content])
  #expect(sections.decisions.isEmpty)
  #expect(artifact.generation.runtime == "stub")
}

@Test
func semanticSectionsRoundTripWithoutDelimiterLoss() throws {
  let sections = SemanticSections(
    summary: "Summary",
    highlights: ["line one\nline two"],
    topics: ["Context Engine"],
    decisions: ["Ship locally"],
    todos: ["Verify device"],
    ideas: ["Reusable runtime"],
    questions: ["When?"]
  )

  let attributes = try SemanticSectionsCodec.attributes(for: sections, language: "ja")

  #expect(attributes["language"] == "ja")
  #expect(try SemanticSectionsCodec.decode(from: attributes) == sections)
}

@Test
func stubRejectsEmptyContext() async throws {
  let data = try fixtureData("contracts/fixtures/context-bundle-v1.json")
  var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  object["items"] = []
  object["budget"] = [
    "unit": "quarter_character_estimate",
    "maximum_units": 4096,
    "included_units": 0,
  ]
  let emptyData = try JSONSerialization.data(withJSONObject: object)
  let empty = try ContractCodec.decode(ContextBundleDocument.self, from: emptyData)

  await #expect(throws: StubIntelligenceRuntimeError.emptyContext) {
    try await StubIntelligenceRuntime().generate(request: request(), context: empty)
  }
}

@Test
func measuredContextTargetIncludesSafetyMargin() {
  let target = ContextWindowPlanner.measuredTarget(
    currentUnits: 4_000,
    measuredTokens: 5_000,
    allowedTokens: 3_000
  )

  #expect(target == 2_160)
  #expect(
    ContextWindowPlanner.measuredTarget(
      currentUnits: 4_000,
      measuredTokens: 3_000,
      allowedTokens: 3_000
    ) == nil
  )
}

@Test
func fallbackContextTargetIsDeterministic() {
  #expect(ContextWindowPlanner.fallbackTarget(currentUnits: 4_000) == 3_000)
  #expect(ContextWindowPlanner.fallbackTarget(currentUnits: 1) == nil)
}

@Test
func promptRendererPreservesCitationsAndLanguage() throws {
  let context = try fixtureBundle()
  let rendered = PromptRenderer.render(request: request(), context: context)

  #expect(rendered.instructions.contains("Write the result in en"))
  #expect(rendered.instructions.contains("daily-summary v1"))
  #expect(rendered.prompt.contains(context.items[0].citationLabel))
  #expect(rendered.prompt.contains(context.items[0].content))
}

@Test
func reducerDelegatesWithoutOwningModelSemantics() async throws {
  let context = try fixtureBundle()
  let reducer = ContextReducer { bundle, maximumUnits in
    #expect(maximumUnits == 32)
    return bundle
  }

  let reduced = try await reducer.reduce(context, maximumUnits: 32)
  #expect(reduced == context)
}

private func request() -> IntelligenceRequest {
  IntelligenceRequest(
    artifactID: "018f6ea2-8f44-7f00-8000-000000000102",
    runID: "018f6ea2-8f44-7f00-8000-000000000202",
    createdAt: "2026-09-13T10:34:00+09:00",
    dayID: DayIDDocument(localDate: "2026-09-13", timezone: "Asia/Tokyo"),
    sessionID: nil,
    promptID: "daily-summary",
    promptVersion: 1,
    language: "en",
    retention: RetentionDocument(type: "days", days: 30)
  )
}

private func fixtureBundle() throws -> ContextBundleDocument {
  try ContractCodec.decode(
    ContextBundleDocument.self,
    from: fixtureData("contracts/fixtures/context-bundle-v1.json")
  )
}

private func fixtureData(_ path: String) throws -> Data {
  let package = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let repository = package.deletingLastPathComponent().deletingLastPathComponent()
  return try Data(contentsOf: repository.appending(path: path))
}
