import ContextCoreKit
import Foundation
import Testing

@testable import ContextCaptureKit

@Test
func mapsFinalSpeechToATimezoneOwnedContextEvent() throws {
  let candidate = TranscriptEventMapper(
    timezoneIdentifier: "Asia/Tokyo",
    deviceID: "ios-local",
    eventID: { "018f6ea2-8f44-7f00-8000-000000000902" },
    now: { Date(timeIntervalSince1970: 1_789_320_700) }
  )
  let mapper = try #require(candidate)
  let segment = TranscriptionSegment(
    text: " 決定しました ",
    localeIdentifier: "ja-JP",
    startTime: 2,
    duration: 1.25,
    isFinal: true
  )

  let event = try mapper.makeEvent(
    from: segment,
    chunkStartedAt: Date(timeIntervalSince1970: 1_789_320_598)
  )
  #expect(event.kind == "transcript")
  #expect(event.payload.content.text == "決定しました")
  #expect(event.dayId.timezone == "Asia/Tokyo")
  #expect(event.metadata["duration_ms"] == "1250")
  #expect(event.source.type == "audio")
}

@Test
func rejectsVolatileSpeechAsPersistableEvidence() throws {
  let candidate = TranscriptEventMapper(timezoneIdentifier: "Asia/Tokyo", deviceID: "ios-local")
  let mapper = try #require(candidate)
  let segment = TranscriptionSegment(
    text: "draft",
    localeIdentifier: "ja-JP",
    startTime: 0,
    duration: 1,
    isFinal: false
  )

  #expect(throws: TranscriptEventMappingFailure.segmentNotFinal) {
    try mapper.makeEvent(from: segment, chunkStartedAt: Date())
  }
}
