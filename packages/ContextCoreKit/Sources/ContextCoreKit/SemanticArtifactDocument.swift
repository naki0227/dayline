public struct SemanticArtifactDocument: Codable, Equatable, Sendable {
  public let schemaVersion: UInt32
  public let id: String
  public let createdAt: String
  public let dayId: DayIDDocument
  public let sessionId: String?
  public let kind: String
  public let content: SemanticContentDocument
  public let sourceEventIds: [String]
  public let sourceArtifactIds: [String]
  public let confidence: Double?
  public let sensitivity: Sensitivity
  public let retention: RetentionDocument
  public let generation: GenerationProvenanceDocument

  public init(
    id: String,
    createdAt: String,
    dayId: DayIDDocument,
    sessionId: String?,
    kind: String,
    content: SemanticContentDocument,
    sourceEventIds: [String],
    sourceArtifactIds: [String],
    confidence: Double?,
    sensitivity: Sensitivity,
    retention: RetentionDocument,
    generation: GenerationProvenanceDocument
  ) {
    schemaVersion = ContextCoreKit.schemaVersion
    self.id = id
    self.createdAt = createdAt
    self.dayId = dayId
    self.sessionId = sessionId
    self.kind = kind
    self.content = content
    self.sourceEventIds = sourceEventIds
    self.sourceArtifactIds = sourceArtifactIds
    self.confidence = confidence
    self.sensitivity = sensitivity
    self.retention = retention
    self.generation = generation
  }

  public func validateVersion() throws {
    try ContractCodec.validate(schemaVersion: schemaVersion)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(schemaVersion, forKey: .schemaVersion)
    try container.encode(id, forKey: .id)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encode(dayId, forKey: .dayId)
    try container.encode(sessionId, forKey: .sessionId)
    try container.encode(kind, forKey: .kind)
    try container.encode(content, forKey: .content)
    try container.encode(sourceEventIds, forKey: .sourceEventIds)
    try container.encode(sourceArtifactIds, forKey: .sourceArtifactIds)
    try container.encode(confidence, forKey: .confidence)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(retention, forKey: .retention)
    try container.encode(generation, forKey: .generation)
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case id
    case createdAt
    case dayId
    case sessionId
    case kind
    case content
    case sourceEventIds
    case sourceArtifactIds
    case confidence
    case sensitivity
    case retention
    case generation
  }
}

public struct DayIDDocument: Codable, Equatable, Sendable {
  public let localDate: String
  public let timezone: String

  public init(localDate: String, timezone: String) {
    self.localDate = localDate
    self.timezone = timezone
  }
}

public struct SemanticContentDocument: Codable, Equatable, Sendable {
  public let text: String
  public let attributes: [String: String]

  public init(text: String, attributes: [String: String]) {
    self.text = text
    self.attributes = attributes
  }
}

public struct RetentionDocument: Codable, Equatable, Sendable {
  public let type: String
  public let days: UInt16?

  public init(type: String, days: UInt16? = nil) {
    self.type = type
    self.days = days
  }
}

public struct GenerationProvenanceDocument: Codable, Equatable, Sendable {
  public let runtime: String
  public let model: String
  public let promptId: String
  public let promptVersion: UInt32
  public let runId: String
  public let generatedAt: String

  public init(
    runtime: String,
    model: String,
    promptId: String,
    promptVersion: UInt32,
    runId: String,
    generatedAt: String
  ) {
    self.runtime = runtime
    self.model = model
    self.promptId = promptId
    self.promptVersion = promptVersion
    self.runId = runId
    self.generatedAt = generatedAt
  }
}
