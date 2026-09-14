import Foundation

public enum DaylineProfileID: String, Codable, CaseIterable, Sendable {
  case dailySummary = "daily-summary"
  case liveMeeting = "live-meeting"
}

public enum ProfileUpdateMode: String, Codable, Sendable {
  case batch
  case incremental
}

public struct ProfileUpdatePolicy: Codable, Equatable, Sendable {
  public let mode: ProfileUpdateMode
  public let minimumIntervalSeconds: UInt16?

  public init(mode: ProfileUpdateMode, minimumIntervalSeconds: UInt16?) {
    self.mode = mode
    self.minimumIntervalSeconds = minimumIntervalSeconds
  }
}

public struct ProfileToolPolicy: Codable, Equatable, Sendable {
  public let read: [String]
  public let write: [String]

  public init(read: [String], write: [String]) {
    self.read = read
    self.write = write
  }
}

public struct DaylineAIProfile: Codable, Equatable, Sendable {
  public let id: DaylineProfileID
  public let version: UInt32
  public let sources: [String]
  public let output: [String]
  public let displayLanguage: String
  public let tools: ProfileToolPolicy
  public let update: ProfileUpdatePolicy

  public init(
    id: DaylineProfileID,
    version: UInt32,
    sources: [String],
    output: [String],
    displayLanguage: String,
    tools: ProfileToolPolicy,
    update: ProfileUpdatePolicy
  ) {
    self.id = id
    self.version = version
    self.sources = sources
    self.output = output
    self.displayLanguage = displayLanguage
    self.tools = tools
    self.update = update
  }

  public func validate() throws {
    guard version > 0 else { throw DaylineProfileError.invalidVersion }
    guard !sources.isEmpty else { throw DaylineProfileError.emptySources }
    guard !output.isEmpty else { throw DaylineProfileError.emptyOutput }
    guard !displayLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw DaylineProfileError.emptyDisplayLanguage
    }
    guard Set(sources).count == sources.count, Set(output).count == output.count else {
      throw DaylineProfileError.duplicateEntry
    }
    if update.mode == .incremental {
      guard let interval = update.minimumIntervalSeconds, interval > 0 else {
        throw DaylineProfileError.invalidUpdateInterval
      }
    }
  }
}

public enum DaylineProfileError: Error, Equatable, Sendable {
  case resourceMissing
  case invalidDocument
  case invalidVersion
  case emptySources
  case emptyOutput
  case emptyDisplayLanguage
  case duplicateEntry
  case invalidUpdateInterval
}
