import AppleIntelligenceKit
import ContextCoreKit
import Foundation
import Testing

@testable import ContextCoreFFIKit

@Test
func buildsContextThroughTheGeneratedRustBinding() throws {
  let request = try fixtureData("fixtures/vertical-slice-request-v1.json")
  let bundle = try RustContextBridge().buildContext(request: request)

  #expect(bundle.schemaVersion == 1)
  #expect(bundle.items.count == 1)
  #expect(bundle.items[0].recordType == .contextEvent)
}

@Test
func shrinksContextThroughTheGeneratedRustBinding() throws {
  let bridge = RustContextBridge()
  let bundle = try bridge.buildContext(
    request: fixtureData("fixtures/vertical-slice-request-v1.json")
  )
  let shrunk = try bridge.shrinkContext(bundle, maximumUnits: 1)

  #expect(shrunk.items.isEmpty)
  #expect(shrunk.budget.maximumUnits == 1)
  #expect(shrunk.budget.includedUnits == 0)
  #expect(shrunk.omissions.last?.reason == "budget")
}

@Test
func persistsAnEventThroughTheGeneratedRustBinding() throws {
  let event = try fixtureData("contracts/fixtures/context-event-v1.json")
  let database = FileManager.default.temporaryDirectory
    .appending(path: "dayline-\(UUID().uuidString).sqlite")
  defer { try? FileManager.default.removeItem(at: database) }

  let persisted = try RustContextBridge().persistEvent(databaseURL: database, event: event)
  #expect(!persisted.isEmpty)
}

@Test
func completesTheEventToArtifactPersistenceSlice() async throws {
  let bridge = RustContextBridge()
  let database = FileManager.default.temporaryDirectory
    .appending(path: "dayline-slice-\(UUID().uuidString).sqlite")
  defer { try? FileManager.default.removeItem(at: database) }

  let event = try fixtureData("contracts/fixtures/context-event-v1.json")
  _ = try bridge.persistEvent(databaseURL: database, event: event)
  let bundle = try bridge.buildContext(
    request: fixtureData("fixtures/vertical-slice-request-v1.json")
  )
  let artifact = try await StubIntelligenceRuntime().generate(
    request: intelligenceRequest(),
    context: bundle
  )
  let persisted = try bridge.persistArtifact(databaseURL: database, artifact: artifact)

  #expect(persisted.sourceEventIds == [bundle.items[0].recordId])
  #expect(persisted.sourceArtifactIds.isEmpty)
  #expect(persisted.content.text.contains("cargo test"))
  #expect(persisted.generation.runtime == "stub")
}

private func intelligenceRequest() -> IntelligenceRequest {
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

private func fixtureData(_ path: String) throws -> Data {
  let package = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let repository = package.deletingLastPathComponent().deletingLastPathComponent()
  return try Data(contentsOf: repository.appending(path: path))
}
