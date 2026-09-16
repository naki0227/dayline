public struct BrowserVisitContextEventDocument: Codable, Equatable, Sendable {
  public let schemaVersion: UInt32
  public let id: String
  public let occurredAt: String
  public let dayId: DayIDDocument
  public let sessionId: String?
  public let source: ContextSourceDocument
  public let kind: String
  public let payload: BrowserVisitPayloadDocument
  public let metadata: [String: String]
  public let sensitivity: Sensitivity
  public let retention: RetentionDocument
  public let provenance: EventProvenanceDocument

  public init(
    id: String, occurredAt: String, dayId: DayIDDocument,
    url: String, title: String?, metadata: [String: String],
    retention: RetentionDocument, provenance: EventProvenanceDocument
  ) {
    schemaVersion = ContextCoreKit.schemaVersion
    self.id = id
    self.occurredAt = occurredAt
    self.dayId = dayId
    sessionId = nil
    source = ContextSourceDocument(type: "browser")
    kind = "visit"
    payload = BrowserVisitPayloadDocument(url: url, title: title)
    self.metadata = metadata
    sensitivity = .sensitive
    self.retention = retention
    self.provenance = provenance
  }

  public func validateVersion() throws {
    try ContractCodec.validate(schemaVersion: schemaVersion)
  }
}

public struct BrowserVisitPayloadDocument: Codable, Equatable, Sendable {
  public let type = "browser_visit"
  public let content: BrowserVisitContentDocument

  public init(url: String, title: String?) {
    content = BrowserVisitContentDocument(url: url, title: title)
  }

  private enum CodingKeys: String, CodingKey { case type, content }
}

public struct BrowserVisitContentDocument: Codable, Equatable, Sendable {
  public let url: String
  public let title: String?

  public init(url: String, title: String?) {
    self.url = url
    self.title = title
  }
}
