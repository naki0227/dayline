import ContextCoreFFIKit
import Darwin
import Foundation
import MacContextKit

@main
struct DaylineMacContextCommand {
  static func main() async {
    do {
      let environment = try Environment()
      try await run(arguments: Array(CommandLine.arguments.dropFirst()), environment: environment)
    } catch {
      let code = failureCode(error)
      FileHandle.standardError.write(Data("dayline-mac-context: \(code)\n".utf8))
      exit(EXIT_FAILURE)
    }
  }

  private static func failureCode(_ error: any Error) -> String {
    switch error {
    case MacContextCollectionFailure.invalidObservation: "invalid_observation"
    case MacContextCollectionFailure.unsupportedTimezone: "unsupported_timezone"
    case MacContextCollectionFailure.historyUnavailable: "history_unavailable"
    case MacContextCollectionFailure.historyReadFailed: "history_read_failed"
    case MacContextCollectionFailure.persistenceFailed: "persistence_failed"
    case MacContextCollectionFailure.settingsUnavailable: "settings_unavailable"
    case CommandFailure.invalidArguments: "invalid_arguments"
    case CommandFailure.invalidInput: "invalid_input"
    default: "operation_failed"
    }
  }

  private static func run(arguments: [String], environment: Environment) async throws {
    guard let command = arguments.first else { throw CommandFailure.invalidArguments }
    switch command {
    case "status":
      let policy = try await environment.settings.load()
      print("shell=\(policy.isEnabled(.shell) ? "enabled" : "disabled")")
      print("browser=\(policy.isEnabled(.browser) ? "enabled" : "disabled")")
    case "configure":
      try await configure(Array(arguments.dropFirst()), environment: environment)
    case "record-shell":
      try await recordShell(environment: environment)
    case "collect-chrome":
      try await collectChrome(environment: environment)
    default:
      throw CommandFailure.invalidArguments
    }
  }

  private static func configure(_ arguments: [String], environment: Environment) async throws {
    guard arguments.count == 2,
      let source = MacContextSource(rawValue: arguments[0]),
      let enabled = enabledValue(arguments[1])
    else { throw CommandFailure.invalidArguments }
    let current = try await environment.settings.load()
    try await environment.settings.save(current.setting(source, enabled: enabled))
    print("\(source.rawValue)=\(enabled ? "enabled" : "disabled")")
  }

  private static func recordShell(environment: Environment) async throws {
    let policy = try await environment.settings.load()
    guard policy.isEnabled(.shell) else {
      print("persisted=0")
      return
    }
    let input = FileHandle.standardInput.readDataToEndOfFile()
    guard input.count <= 64 * 1_024 else { throw CommandFailure.invalidInput }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let observation = try decoder.decode(ShellCommandObservation.self, from: input)
    let persisted = try await environment.collector.collectShell(observation)
    print(persisted ? "persisted=1" : "persisted=0")
  }

  private static func collectChrome(environment: Environment) async throws {
    let policy = try await environment.settings.load()
    guard policy.isEnabled(.browser) else {
      print("persisted=0")
      return
    }
    let cursor = try environment.cursor.load()
    let batch = try environment.chrome.visits(after: cursor)
    let persisted = try await environment.collector.collectChrome(batch.observations)
    if persisted > 0 {
      try environment.cursor.save(batch.nextCursor)
    }
    print("persisted=\(persisted)")
  }

  private static func enabledValue(_ value: String) -> Bool? {
    switch value {
    case "on", "enabled": true
    case "off", "disabled": false
    default: nil
    }
  }
}

private struct Environment {
  let settings: MacCollectorSettingsStore
  let collector: MacContextCollector
  let chrome: ChromeHistorySQLiteReader
  let cursor: ChromeCursorStore

  init(
    fileManager: FileManager = .default,
    processInfo: ProcessInfo = .processInfo
  ) throws {
    let dayline: URL
    if let override = processInfo.environment["DAYLINE_DATA_DIRECTORY"], !override.isEmpty {
      dayline = URL(filePath: override, directoryHint: .isDirectory)
    } else {
      guard
        let support = fileManager.urls(
          for: .applicationSupportDirectory,
          in: .userDomainMask
        ).first
      else { throw CommandFailure.unavailable }
      dayline = support.appendingPathComponent("Dayline", isDirectory: true)
    }
    try fileManager.createDirectory(at: dayline, withIntermediateDirectories: true)
    let settings = MacCollectorSettingsStore(
      fileURL: dayline.appendingPathComponent("mac-context-policy.json")
    )
    let factory = try Self.factory(defaults: .standard)
    self.settings = settings
    collector = MacContextCollector(
      settings: settings,
      persistence: RustContextStore(databaseURL: dayline.appendingPathComponent("context.sqlite")),
      factory: factory
    )
    let chromeHistory =
      processInfo.environment["DAYLINE_CHROME_HISTORY"].map { URL(filePath: $0) }
      ?? Self.chromeHistory(fileManager: fileManager)
    chrome = ChromeHistorySQLiteReader(historyURL: chromeHistory)
    cursor = ChromeCursorStore(fileURL: dayline.appendingPathComponent("chrome-cursor.json"))
  }

  private static func factory(defaults: UserDefaults) throws -> MacContextEventFactory {
    let key = "dayline.mac-installation-id"
    let deviceID: String
    if let existing = defaults.string(forKey: key), !existing.isEmpty {
      deviceID = existing
    } else {
      deviceID = UUID().uuidString.lowercased()
      defaults.set(deviceID, forKey: key)
    }
    guard
      let factory = MacContextEventFactory(
        timezoneIdentifier: TimeZone.current.identifier,
        deviceID: deviceID
      )
    else { throw CommandFailure.unavailable }
    return factory
  }

  private static func chromeHistory(fileManager: FileManager) -> URL {
    fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/Google/Chrome/Default/History")
  }
}

private struct ChromeCursorStore {
  let fileURL: URL

  func load() throws -> ChromeHistoryCursor {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return ChromeHistoryCursor(date: Date().addingTimeInterval(-3_600))
    }
    return try JSONDecoder().decode(
      ChromeHistoryCursor.self,
      from: Data(contentsOf: fileURL)
    )
  }

  func save(_ cursor: ChromeHistoryCursor) throws {
    try JSONEncoder().encode(cursor).write(to: fileURL, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
  }
}

private enum CommandFailure: Error {
  case invalidArguments
  case invalidInput
  case unavailable
}
