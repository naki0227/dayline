import ContextCoreKit
import Foundation
import Testing

@testable import ContextCaptureKit

private enum StoreFailure: Error {
  case unavailable
}

private struct FailingEventStore: ContextEventPersisting {
  func persist(
    _: TextContextEventDocument
  ) async throws -> TextContextEventDocument {
    throw StoreFailure.unavailable
  }
}

@Test
func mapsPersistenceErrorsToAContentFreeFailure() async throws {
  let mapperCandidate = TranscriptEventMapper(
    timezoneIdentifier: "Asia/Tokyo",
    deviceID: "ios-test"
  )
  let mapper = try #require(mapperCandidate)
  let pipeline = TranscriptEventPipeline(mapper: mapper, store: FailingEventStore())
  let segment = TranscriptionSegment(
    text: "private transcript",
    localeIdentifier: "en-US",
    startTime: 0,
    duration: 1,
    isFinal: true
  )

  await #expect(throws: TranscriptEventPipelineFailure.persistenceFailed) {
    try await pipeline.process(segment, chunkStartedAt: Date())
  }
}
