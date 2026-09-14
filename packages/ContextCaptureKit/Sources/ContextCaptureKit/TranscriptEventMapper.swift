import ContextCoreKit
import Foundation

public enum TranscriptEventMappingFailure: Error, Equatable, Sendable {
  case segmentNotFinal
  case emptyText
  case invalidTimezone
}

public struct TranscriptEventMapper: Sendable {
  private let timezone: TimeZone
  private let deviceID: String
  private let eventID: @Sendable () -> String
  private let now: @Sendable () -> Date

  public init?(
    timezoneIdentifier: String,
    deviceID: String,
    eventID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    guard let timezone = TimeZone(identifier: timezoneIdentifier) else { return nil }
    self.timezone = timezone
    self.deviceID = deviceID
    self.eventID = eventID
    self.now = now
  }

  public func makeEvent(
    from segment: TranscriptionSegment,
    chunkStartedAt: Date,
    sessionID: String? = nil
  ) throws -> TextContextEventDocument {
    guard segment.isFinal else { throw TranscriptEventMappingFailure.segmentNotFinal }
    let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw TranscriptEventMappingFailure.emptyText }
    let occurredAt = chunkStartedAt.addingTimeInterval(segment.startTime)
    return TextContextEventDocument(
      id: eventID(),
      occurredAt: timestamp(occurredAt),
      dayId: DayIDDocument(
        localDate: localDate(occurredAt),
        timezone: timezone.identifier
      ),
      sessionId: sessionID,
      source: ContextSourceDocument(type: "audio"),
      kind: "transcript",
      payload: TextPayloadDocument(text: text),
      metadata: [
        "duration_ms": String(Int((segment.duration * 1_000).rounded())),
        "finalized": "true",
        "locale": segment.localeIdentifier,
      ],
      sensitivity: .sensitive,
      retention: RetentionDocument(type: "days", days: 30),
      provenance: EventProvenanceDocument(
        collector: "ios-speech",
        deviceId: deviceID,
        capturedAt: timestamp(now())
      )
    )
  }

  private func timestamp(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }

  private func localDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timezone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}
