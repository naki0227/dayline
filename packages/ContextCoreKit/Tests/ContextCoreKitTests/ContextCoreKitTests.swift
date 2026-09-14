import Foundation
import Testing

@testable import ContextCoreKit

@Test
func schemaVersionStartsAtOne() {
  #expect(ContextCoreKit.schemaVersion == 1)
}

@Test
func decodesTheContextBundleFixture() throws {
  let fixture = try fixtureData("contracts/fixtures/context-bundle-v1.json")
  let bundle = try ContractCodec.decode(ContextBundleDocument.self, from: fixture)
  try bundle.validateVersion()

  #expect(bundle.items.count == 1)
  #expect(bundle.budget.unit == "quarter_character_estimate")
  #expect(bundle.items[0].recordType == .semanticArtifact)
}

@Test
func semanticArtifactRoundTrips() throws {
  let fixture = try fixtureData("contracts/fixtures/semantic-artifact-v1.json")
  let artifact = try ContractCodec.decode(SemanticArtifactDocument.self, from: fixture)
  try artifact.validateVersion()
  let encoded = try ContractCodec.encode(artifact)
  let decoded = try ContractCodec.decode(SemanticArtifactDocument.self, from: encoded)

  #expect(decoded == artifact)
}

@Test
func textContextEventEncodesTheV1Shape() throws {
  let event = TextContextEventDocument(
    id: "018f6ea2-8f44-7f00-8000-000000000901",
    occurredAt: "2026-09-14T01:00:00Z",
    dayId: DayIDDocument(localDate: "2026-09-14", timezone: "Asia/Tokyo"),
    sessionId: nil,
    source: ContextSourceDocument(type: "audio"),
    kind: "transcript",
    payload: TextPayloadDocument(text: "こんにちは"),
    metadata: ["finalized": "true"],
    sensitivity: .sensitive,
    retention: RetentionDocument(type: "days", days: 30),
    provenance: EventProvenanceDocument(
      collector: "ios-speech",
      deviceId: "device-local",
      capturedAt: "2026-09-14T01:00:01Z"
    )
  )

  let data = try ContractCodec.encode(event)
  let value = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  #expect(value["schema_version"] as? Int == 1)
  #expect(value["kind"] as? String == "transcript")
  let payload = try #require(value["payload"] as? [String: Any])
  #expect(payload["type"] as? String == "text")
}

private func fixtureData(_ path: String) throws -> Data {
  let package = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let repository = package.deletingLastPathComponent().deletingLastPathComponent()
  return try Data(contentsOf: repository.appending(path: path))
}
