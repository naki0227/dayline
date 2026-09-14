import ContextCoreKit

public struct IntelligenceRequest: Equatable, Sendable {
  public let artifactID: String
  public let runID: String
  public let createdAt: String
  public let dayID: DayIDDocument
  public let sessionID: String?
  public let promptID: String
  public let promptVersion: UInt32
  public let language: String
  public let retention: RetentionDocument

  public init(
    artifactID: String,
    runID: String,
    createdAt: String,
    dayID: DayIDDocument,
    sessionID: String?,
    promptID: String,
    promptVersion: UInt32,
    language: String,
    retention: RetentionDocument
  ) {
    self.artifactID = artifactID
    self.runID = runID
    self.createdAt = createdAt
    self.dayID = dayID
    self.sessionID = sessionID
    self.promptID = promptID
    self.promptVersion = promptVersion
    self.language = language
    self.retention = retention
  }
}

/// Runtime boundary that consumes an assembled bundle and returns generated meaning.
public protocol IntelligenceRuntime: Sendable {
  func generate(
    request: IntelligenceRequest,
    context: ContextBundleDocument
  ) async throws -> SemanticArtifactDocument
}
