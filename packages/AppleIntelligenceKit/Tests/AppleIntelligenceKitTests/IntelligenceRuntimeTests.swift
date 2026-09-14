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
  #expect(artifact.generation.runtime == "stub")
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
