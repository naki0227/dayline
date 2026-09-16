import Foundation

public struct ShellCommandObservation: Codable, Equatable, Sendable {
  public let command: String
  public let cwd: String
  public let exitCode: Int?
  public let durationMilliseconds: UInt64?
  public let occurredAt: Date

  public init(
    command: String,
    cwd: String,
    exitCode: Int?,
    durationMilliseconds: UInt64?,
    occurredAt: Date
  ) {
    self.command = command
    self.cwd = cwd
    self.exitCode = exitCode
    self.durationMilliseconds = durationMilliseconds
    self.occurredAt = occurredAt
  }
}

public struct ChromeVisitObservation: Equatable, Sendable {
  public let url: URL
  public let title: String?
  public let occurredAt: Date

  public init(url: URL, title: String?, occurredAt: Date) {
    self.url = url
    self.title = title
    self.occurredAt = occurredAt
  }
}

public enum MacContextCollectionFailure: Error, Equatable, Sendable {
  case invalidObservation
  case unsupportedTimezone
  case historyUnavailable
  case historyReadFailed
  case persistenceFailed
  case settingsUnavailable
}
