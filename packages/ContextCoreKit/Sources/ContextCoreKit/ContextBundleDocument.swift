public struct ContextBundleDocument: Codable, Equatable, Sendable {
  public let schemaVersion: UInt32
  public let id: String
  public let builtAt: String
  public let task: ContextTaskDocument
  public let profile: VersionedIdentifierDocument
  public let window: ContextWindowDocument
  public let items: [ContextItemDocument]
  public let budget: ContextBudgetDocument
  public let processing: ContextProcessingDocument
  public let suggestedTools: [SuggestedToolDocument]
  public let omissions: [ContextOmissionDocument]
  public let assembly: AssemblyProvenanceDocument

  public func validateVersion() throws {
    try ContractCodec.validate(schemaVersion: schemaVersion)
  }
}

public struct ContextTaskDocument: Codable, Equatable, Sendable {
  public let id: String
  public let objective: String
}

public struct VersionedIdentifierDocument: Codable, Equatable, Sendable {
  public let id: String
  public let version: UInt32
}

public struct ContextWindowDocument: Codable, Equatable, Sendable {
  public let start: String
  public let end: String
  public let timezone: String
}

public struct ContextItemDocument: Codable, Equatable, Sendable {
  public let recordType: ContextRecordType
  public let recordId: String
  public let occurredAt: String
  public let content: String
  public let contentFormat: ContentFormat
  public let sensitivity: Sensitivity
  public let relevanceScore: Double
  public let estimatedUnits: UInt64
  public let citationLabel: String
}

public enum ContextRecordType: String, Codable, Sendable {
  case contextEvent = "context_event"
  case semanticArtifact = "semantic_artifact"
}

public enum ContentFormat: String, Codable, Sendable {
  case plainText = "plain_text"
  case json
}

public enum Sensitivity: String, Codable, Sendable {
  case standard
  case sensitive
  case restricted
}

public struct ContextBudgetDocument: Codable, Equatable, Sendable {
  public let unit: String
  public let maximumUnits: UInt64
  public let includedUnits: UInt64
}

public struct ContextProcessingDocument: Codable, Equatable, Sendable {
  public let location: String
}

public struct SuggestedToolDocument: Codable, Equatable, Sendable {
  public let name: String
  public let access: String
  public let reason: String
}

public struct ContextOmissionDocument: Codable, Equatable, Sendable {
  public let reason: String
  public let count: UInt64
}

public struct AssemblyProvenanceDocument: Codable, Equatable, Sendable {
  public let engine: String
  public let engineVersion: String
  public let policyVersion: UInt32
  public let rankingVersion: UInt32
}
