public struct TextContextEventDocument: Codable, Equatable, Sendable {
  public let schemaVersion: UInt32
  public let id: String
  public let occurredAt: String
  public let dayId: DayIDDocument
  public let sessionId: String?
  public let source: ContextSourceDocument
  public let kind: String
  public let payload: TextPayloadDocument
  public let metadata: [String: String]
  public let sensitivity: Sensitivity
  public let retention: RetentionDocument
  public let provenance: EventProvenanceDocument

  public init(
    id: String,
    occurredAt: String,
    dayId: DayIDDocument,
    sessionId: String?,
    source: ContextSourceDocument,
    kind: String,
    payload: TextPayloadDocument,
    metadata: [String: String],
    sensitivity: Sensitivity,
    retention: RetentionDocument,
    provenance: EventProvenanceDocument
  ) {
    schemaVersion = ContextCoreKit.schemaVersion
    self.id = id
    self.occurredAt = occurredAt
    self.dayId = dayId
    self.sessionId = sessionId
    self.source = source
    self.kind = kind
    self.payload = payload
    self.metadata = metadata
    self.sensitivity = sensitivity
    self.retention = retention
    self.provenance = provenance
  }

  public func validateVersion() throws {
    try ContractCodec.validate(schemaVersion: schemaVersion)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(schemaVersion, forKey: .schemaVersion)
    try container.encode(id, forKey: .id)
    try container.encode(occurredAt, forKey: .occurredAt)
    try container.encode(dayId, forKey: .dayId)
    try container.encode(sessionId, forKey: .sessionId)
    try container.encode(source, forKey: .source)
    try container.encode(kind, forKey: .kind)
    try container.encode(payload, forKey: .payload)
    try container.encode(metadata, forKey: .metadata)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(retention, forKey: .retention)
    try container.encode(provenance, forKey: .provenance)
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case id
    case occurredAt
    case dayId
    case sessionId
    case source
    case kind
    case payload
    case metadata
    case sensitivity
    case retention
    case provenance
  }
}

public struct ContextSourceDocument: Codable, Equatable, Sendable {
  public let type: String
  public let identifier: String?

  public init(type: String, identifier: String? = nil) {
    self.type = type
    self.identifier = identifier
  }
}

public struct TextPayloadDocument: Codable, Equatable, Sendable {
  public let type: String
  public let content: TextContentDocument

  public init(text: String) {
    type = "text"
    content = TextContentDocument(text: text)
  }
}

public struct TextContentDocument: Codable, Equatable, Sendable {
  public let text: String

  public init(text: String) {
    self.text = text
  }
}

public struct EventProvenanceDocument: Codable, Equatable, Sendable {
  public let collector: String
  public let deviceId: String
  public let capturedAt: String

  public init(collector: String, deviceId: String, capturedAt: String) {
    self.collector = collector
    self.deviceId = deviceId
    self.capturedAt = capturedAt
  }
}
