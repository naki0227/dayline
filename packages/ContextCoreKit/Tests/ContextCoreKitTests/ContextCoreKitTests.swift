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
func actionProposalRoundTripsWithRequiredNullAndGenericArguments() throws {
  let fixture = try fixtureData("contracts/fixtures/action-proposal-v1.json")
  let proposal = try ContractCodec.decode(ActionProposalDocument.self, from: fixture)
  try proposal.validateVersion()
  let encoded = try ContractCodec.encode(proposal)
  let value = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
  let decoded = try ContractCodec.decode(ActionProposalDocument.self, from: encoded)

  #expect(decoded == proposal)
  #expect(proposal.arguments["body"] == .string("The ContextEvent contract was completed."))
  #expect(value.keys.contains("expires_at"))
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
  #expect(value["session_id"] is NSNull)
  let payload = try #require(value["payload"] as? [String: Any])
  #expect(payload["type"] as? String == "text")

  let decoded = try ContractCodec.decode(TextContextEventDocument.self, from: data)
  try decoded.validateVersion()
  #expect(decoded == event)
}

@Test
func semanticArtifactKeepsRequiredNullFields() throws {
  let artifact = SemanticArtifactDocument(
    id: "018f6ea2-8f44-7f00-8000-000000000903",
    createdAt: "2026-09-14T12:00:00Z",
    dayId: DayIDDocument(localDate: "2026-09-14", timezone: "Asia/Tokyo"),
    sessionId: nil,
    kind: "summary",
    content: SemanticContentDocument(text: "Summary", attributes: [:]),
    sourceEventIds: ["018f6ea2-8f44-7f00-8000-000000000901"],
    sourceArtifactIds: [],
    confidence: nil,
    sensitivity: .sensitive,
    retention: RetentionDocument(type: "days", days: 30),
    generation: GenerationProvenanceDocument(
      runtime: "apple-foundation-models",
      model: "system-language-model",
      promptId: "daily-summary",
      promptVersion: 1,
      runId: "018f6ea2-8f44-7f00-8000-000000000904",
      generatedAt: "2026-09-14T12:00:00Z"
    )
  )
  let data = try ContractCodec.encode(artifact)
  let value = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

  #expect(value.keys.contains("session_id"))
  #expect(value["session_id"] is NSNull)
  #expect(value.keys.contains("confidence"))
  #expect(value["confidence"] is NSNull)
}

@Test
func storedContextRequestEncodesForTheRustBoundary() throws {
  let request = storedContextRequest()
  let data = try ContractCodec.encode(request)
  let value = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

  #expect(value["request_version"] as? Int == 1)
  #expect((value["day_id"] as? [String: Any])?["timezone"] as? String == "Asia/Tokyo")
  let decoded = try ContractCodec.decode(StoredContextRequestDocument.self, from: data)
  try decoded.validateVersion()
  #expect(decoded == request)
}

private func storedContextRequest() -> StoredContextRequestDocument {
  StoredContextRequestDocument(
    dayId: DayIDDocument(localDate: "2026-09-14", timezone: "Asia/Tokyo"),
    plan: StoredContextPlanDocument(
      id: "018f6ea2-8f44-7f00-8000-000000000902",
      builtAt: "2026-09-14T12:00:00Z",
      task: ContextTaskDocument(id: "daily_summary", objective: "Summarize the day."),
      profile: VersionedIdentifierDocument(id: "daily-summary", version: 1),
      timezone: "Asia/Tokyo",
      processing: ContextProcessingDocument(location: "on_device_only"),
      suggestedTools: [],
      assembly: AssemblyProvenanceDocument(
        engine: "context-core",
        engineVersion: "0.1.0",
        policyVersion: 1,
        rankingVersion: 1
      )
    ),
    query: StoredContextQueryDocument(
      start: "2026-09-13T15:00:00Z",
      end: "2026-09-14T15:00:00Z",
      sources: [],
      sessionId: nil,
      projectHint: nil,
      maximumSensitivity: .sensitive,
      maximumContextUnits: 4_096
    )
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
