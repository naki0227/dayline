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
func persistsAnEventThroughTheGeneratedRustBinding() throws {
  let event = try fixtureData("contracts/fixtures/context-event-v1.json")
  let database = FileManager.default.temporaryDirectory
    .appending(path: "dayline-\(UUID().uuidString).sqlite")
  defer { try? FileManager.default.removeItem(at: database) }

  let persisted = try RustContextBridge().persistEvent(databaseURL: database, event: event)
  #expect(!persisted.isEmpty)
}

private func fixtureData(_ path: String) throws -> Data {
  let package = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let repository = package.deletingLastPathComponent().deletingLastPathComponent()
  return try Data(contentsOf: repository.appending(path: path))
}
