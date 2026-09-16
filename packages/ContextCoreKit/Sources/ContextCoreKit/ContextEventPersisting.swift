import Foundation

public protocol ContextEventPersisting: Sendable {
  func persist(
    _ event: TextContextEventDocument
  ) async throws -> TextContextEventDocument
}

public protocol ContextEventDataPersisting: Sendable {
  func persistEventData(_ event: Data) async throws -> Data
}
