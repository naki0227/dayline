public protocol ContextEventPersisting: Sendable {
  func persist(
    _ event: TextContextEventDocument
  ) async throws -> TextContextEventDocument
}
