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

private func fixtureData(_ path: String) throws -> Data {
  let package = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let repository = package.deletingLastPathComponent().deletingLastPathComponent()
  return try Data(contentsOf: repository.appending(path: path))
}
