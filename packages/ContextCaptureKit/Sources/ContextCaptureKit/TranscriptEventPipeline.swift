import ContextCoreKit
import Foundation

public enum TranscriptEventPipelineFailure: Error, Equatable, Sendable {
  case invalidEvent
  case persistenceFailed
}

public struct TranscriptEventPipeline: Sendable {
  private let mapper: TranscriptEventMapper
  private let store: any ContextEventPersisting

  public init(
    mapper: TranscriptEventMapper,
    store: any ContextEventPersisting
  ) {
    self.mapper = mapper
    self.store = store
  }

  public func process(
    _ segment: TranscriptionSegment,
    chunkStartedAt: Date,
    sessionID: String? = nil
  ) async throws -> TextContextEventDocument {
    let event: TextContextEventDocument
    do {
      event = try mapper.makeEvent(
        from: segment,
        chunkStartedAt: chunkStartedAt,
        sessionID: sessionID
      )
    } catch {
      throw TranscriptEventPipelineFailure.invalidEvent
    }

    do {
      return try await store.persist(event)
    } catch {
      throw TranscriptEventPipelineFailure.persistenceFailed
    }
  }
}
