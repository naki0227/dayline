import ContextCoreKit
import Foundation

public struct MacContextEventFactory: Sendable {
  private let timezone: TimeZone
  private let deviceID: String
  private let eventID: @Sendable () -> String
  private let capturedAt: @Sendable () -> Date

  public init?(
    timezoneIdentifier: String,
    deviceID: String,
    eventID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
    capturedAt: @escaping @Sendable () -> Date = Date.init
  ) {
    guard let timezone = TimeZone(identifier: timezoneIdentifier), !deviceID.isEmpty else {
      return nil
    }
    self.timezone = timezone
    self.deviceID = deviceID
    self.eventID = eventID
    self.capturedAt = capturedAt
  }

  public func shell(_ observation: ShellCommandObservation) throws -> Data {
    let command = observation.command.trimmingCharacters(in: .whitespacesAndNewlines)
    let cwd = observation.cwd.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !command.isEmpty, !cwd.isEmpty else {
      throw MacContextCollectionFailure.invalidObservation
    }
    let document = ShellCommandContextEventDocument(
      id: eventID(),
      occurredAt: iso8601(observation.occurredAt),
      dayId: dayID(for: observation.occurredAt),
      command: command,
      cwd: cwd,
      exitCode: observation.exitCode,
      durationMilliseconds: observation.durationMilliseconds,
      metadata: ["redaction": "rust-pre-persistence"],
      retention: RetentionDocument(type: "days", days: 30),
      provenance: provenance()
    )
    return try ContractCodec.encode(document)
  }

  public func browser(_ observation: ChromeVisitObservation) throws -> Data {
    guard let scheme = observation.url.scheme?.lowercased(), ["http", "https"].contains(scheme)
    else {
      throw MacContextCollectionFailure.invalidObservation
    }
    let document = BrowserVisitContextEventDocument(
      id: eventID(),
      occurredAt: iso8601(observation.occurredAt),
      dayId: dayID(for: observation.occurredAt),
      url: observation.url.absoluteString,
      title: observation.title?.trimmingCharacters(in: .whitespacesAndNewlines),
      metadata: ["browser": "chrome"],
      retention: RetentionDocument(type: "days", days: 30),
      provenance: provenance()
    )
    return try ContractCodec.encode(document)
  }

  private func dayID(for date: Date) -> DayIDDocument {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timezone
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let localDate = String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
    return DayIDDocument(localDate: localDate, timezone: timezone.identifier)
  }

  private func provenance() -> EventProvenanceDocument {
    EventProvenanceDocument(
      collector: "dayline-mac-context",
      deviceId: deviceID,
      capturedAt: iso8601(capturedAt())
    )
  }

  private func iso8601(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }
}
