public struct StoredContextRequestDocument: Codable, Equatable, Sendable {
  public let requestVersion: UInt32
  public let dayId: DayIDDocument
  public let plan: StoredContextPlanDocument
  public let query: StoredContextQueryDocument

  public init(
    dayId: DayIDDocument,
    plan: StoredContextPlanDocument,
    query: StoredContextQueryDocument
  ) {
    requestVersion = ContextCoreKit.schemaVersion
    self.dayId = dayId
    self.plan = plan
    self.query = query
  }

  public func validateVersion() throws {
    try ContractCodec.validate(schemaVersion: requestVersion)
  }
}

public struct StoredContextPlanDocument: Codable, Equatable, Sendable {
  public let id: String
  public let builtAt: String
  public let task: ContextTaskDocument
  public let profile: VersionedIdentifierDocument
  public let timezone: String
  public let processing: ContextProcessingDocument
  public let suggestedTools: [SuggestedToolDocument]
  public let assembly: AssemblyProvenanceDocument

  public init(
    id: String,
    builtAt: String,
    task: ContextTaskDocument,
    profile: VersionedIdentifierDocument,
    timezone: String,
    processing: ContextProcessingDocument,
    suggestedTools: [SuggestedToolDocument],
    assembly: AssemblyProvenanceDocument
  ) {
    self.id = id
    self.builtAt = builtAt
    self.task = task
    self.profile = profile
    self.timezone = timezone
    self.processing = processing
    self.suggestedTools = suggestedTools
    self.assembly = assembly
  }
}

public struct StoredContextQueryDocument: Codable, Equatable, Sendable {
  public let start: String
  public let end: String
  public let sources: [ContextSourceDocument]
  public let sessionId: String?
  public let projectHint: String?
  public let maximumSensitivity: Sensitivity
  public let maximumContextUnits: UInt64

  public init(
    start: String,
    end: String,
    sources: [ContextSourceDocument],
    sessionId: String?,
    projectHint: String?,
    maximumSensitivity: Sensitivity,
    maximumContextUnits: UInt64
  ) {
    self.start = start
    self.end = end
    self.sources = sources
    self.sessionId = sessionId
    self.projectHint = projectHint
    self.maximumSensitivity = maximumSensitivity
    self.maximumContextUnits = maximumContextUnits
  }
}

public protocol StoredContextBuilding: Sendable {
  func buildStoredContext(
    _ request: StoredContextRequestDocument
  ) async throws -> ContextBundleDocument
}

public protocol SemanticArtifactPersisting: Sendable {
  func persist(
    _ artifact: SemanticArtifactDocument
  ) async throws -> SemanticArtifactDocument
}
