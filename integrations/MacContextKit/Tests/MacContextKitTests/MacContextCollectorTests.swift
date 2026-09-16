import ContextCoreKit
import Foundation
import SQLite3
import XCTest

@testable import MacContextKit

final class MacContextCollectorTests: XCTestCase {
  func testCollectorsAreDisabledByDefaultAndNeverPersist() async throws {
    let fixture = try makeFixture()
    let shell = ShellCommandObservation(
      command: "cargo test", cwd: "/workspace/dayline", exitCode: 0,
      durationMilliseconds: 100, occurredAt: fixture.now
    )

    let shellPersisted = try await fixture.collector.collectShell(shell)
    XCTAssertFalse(shellPersisted)
    let url = try XCTUnwrap(URL(string: "https://example.com"))
    let count = try await fixture.collector.collectChrome([
      ChromeVisitObservation(url: url, title: "Example", occurredAt: fixture.now)
    ])
    XCTAssertEqual(count, 0)
    let documents = await fixture.persistence.documents()
    XCTAssertTrue(documents.isEmpty)
  }

  func testEnabledCollectorsPersistStrictShellAndBrowserEvents() async throws {
    let fixture = try makeFixture()
    try await fixture.settings.save(MacCollectorPolicy(enabledSources: [.shell, .browser]))
    let shell = ShellCommandObservation(
      command: "cargo test", cwd: "/workspace/dayline", exitCode: 0,
      durationMilliseconds: 425, occurredAt: fixture.now
    )
    let browser = ChromeVisitObservation(
      url: try XCTUnwrap(URL(string: "https://example.com/docs")),
      title: "Docs", occurredAt: fixture.now
    )

    let shellPersisted = try await fixture.collector.collectShell(shell)
    let browserCount = try await fixture.collector.collectChrome([browser])
    XCTAssertTrue(shellPersisted)
    XCTAssertEqual(browserCount, 1)
    let documents = await fixture.persistence.documents()
    XCTAssertEqual(documents.count, 2)
    let shellJSON = try jsonObject(documents[0])
    let browserJSON = try jsonObject(documents[1])
    let shellPayload = try XCTUnwrap(shellJSON["payload"] as? [String: Any])
    let browserPayload = try XCTUnwrap(browserJSON["payload"] as? [String: Any])
    let shellSource = try XCTUnwrap(shellJSON["source"] as? [String: Any])

    XCTAssertEqual(shellSource["type"] as? String, "shell")
    XCTAssertEqual(shellPayload["type"] as? String, "shell_command")
    XCTAssertEqual(browserPayload["type"] as? String, "browser_visit")
    XCTAssertNil(shellJSON["stdout"])
    XCTAssertNil(shellJSON["stderr"])
  }

  func testChromeReaderReturnsOnlyVisitsAfterTheCursor() throws {
    let databaseURL = try temporaryDirectory().appendingPathComponent("History")
    try createChromeHistory(at: databaseURL)
    let batch = try ChromeHistorySQLiteReader(historyURL: databaseURL).visits(
      after: ChromeHistoryCursor(date: Date(timeIntervalSince1970: 1_700_000_000))
    )

    XCTAssertEqual(batch.observations.count, 1)
    XCTAssertEqual(batch.observations[0].url.absoluteString, "https://example.com/after")
    XCTAssertEqual(batch.observations[0].title, "After")
    XCTAssertEqual(batch.nextCursor.visitID, 2)
  }
}

private struct CollectorFixture {
  let now: Date
  let settings: MacCollectorSettingsStore
  let persistence: PersistenceProbe
  let collector: MacContextCollector
}

private func makeFixture() throws -> CollectorFixture {
  let now = Date(timeIntervalSince1970: 1_700_000_100)
  let settings = MacCollectorSettingsStore(
    fileURL: try temporaryDirectory().appendingPathComponent("policy.json")
  )
  let persistence = PersistenceProbe()
  let factory = try XCTUnwrap(
    MacContextEventFactory(
      timezoneIdentifier: "Asia/Tokyo", deviceID: "mac-test",
      eventID: { UUID().uuidString.lowercased() }, capturedAt: { now }
    )
  )
  return CollectorFixture(
    now: now,
    settings: settings,
    persistence: persistence,
    collector: MacContextCollector(settings: settings, persistence: persistence, factory: factory)
  )
}

private actor PersistenceProbe: ContextEventDataPersisting {
  private var persisted: [Data] = []

  func persistEventData(_ event: Data) -> Data {
    persisted.append(event)
    return event
  }

  func documents() -> [Data] { persisted }
}

private func temporaryDirectory() throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}

private func jsonObject(_ data: Data) throws -> [String: Any] {
  try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func createChromeHistory(at url: URL) throws {
  var database: OpaquePointer?
  guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
    throw MacContextCollectionFailure.historyUnavailable
  }
  defer { sqlite3_close(database) }
  let offset = 11_644_473_600.0
  let before = Int64((1_699_999_900 + offset) * 1_000_000)
  let after = Int64((1_700_000_100 + offset) * 1_000_000)
  let statements = [
    "CREATE TABLE urls (id INTEGER PRIMARY KEY, url TEXT, title TEXT)",
    "CREATE TABLE visits (id INTEGER PRIMARY KEY, url INTEGER, visit_time INTEGER)",
    "INSERT INTO urls VALUES (1, 'https://example.com/before', 'Before')",
    "INSERT INTO urls VALUES (2, 'https://example.com/after', 'After')",
    "INSERT INTO visits VALUES (1, 1, \(before))",
    "INSERT INTO visits VALUES (2, 2, \(after))",
  ]
  for statement in statements where sqlite3_exec(database, statement, nil, nil, nil) != SQLITE_OK {
    throw MacContextCollectionFailure.historyReadFailed
  }
}
