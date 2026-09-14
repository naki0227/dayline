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

  public init(
    schemaVersion: UInt32 = ContextCoreKit.schemaVersion,
    id: String,
    builtAt: String,
    task: ContextTaskDocument,
    profile: VersionedIdentifierDocument,
    window: ContextWindowDocument,
    items: [ContextItemDocument],
    budget: ContextBudgetDocument,
    processing: ContextProcessingDocument,
    suggestedTools: [SuggestedToolDocument],
    omissions: [ContextOmissionDocument],
    assembly: AssemblyProvenanceDocument
  ) {
    self.schemaVersion = schemaVersion
    self.id = id
    self.builtAt = builtAt
    self.task = task
    self.profile = profile
    self.window = window
    self.items = items
    self.budget = budget
    self.processing = processing
    self.suggestedTools = suggestedTools
    self.omissions = omissions
    self.assembly = assembly
  }

  public func validateVersion() throws {
    try ContractCodec.validate(schemaVersion: schemaVersion)
  }
}

public struct ContextTaskDocument: Codable, Equatable, Sendable {
  public let id: String
  public let objective: String

  public init(id: String, objective: String) {
    self.id = id
    self.objective = objective
  }
}

public struct VersionedIdentifierDocument: Codable, Equatable, Sendable {
  public let id: String
  public let version: UInt32

  public init(id: String, version: UInt32) {
    self.id = id
    self.version = version
  }
}

public struct ContextWindowDocument: Codable, Equatable, Sendable {
  public let start: String
  public let end: String
  public let timezone: String

  public init(start: String, end: String, timezone: String) {
    self.start = start
    self.end = end
    self.timezone = timezone
  }
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

  public init(
    recordType: ContextRecordType,
    recordId: String,
    occurredAt: String,
    content: String,
    contentFormat: ContentFormat,
    sensitivity: Sensitivity,
    relevanceScore: Double,
    estimatedUnits: UInt64,
    citationLabel: String
  ) {
    self.recordType = recordType
    self.recordId = recordId
    self.occurredAt = occurredAt
    self.content = content
    self.contentFormat = contentFormat
    self.sensitivity = sensitivity
    self.relevanceScore = relevanceScore
    self.estimatedUnits = estimatedUnits
    self.citationLabel = citationLabel
  }
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

  public init(
    unit: String = "quarter_character_estimate",
    maximumUnits: UInt64,
    includedUnits: UInt64
  ) {
    self.unit = unit
    self.maximumUnits = maximumUnits
    self.includedUnits = includedUnits
  }
}

public struct ContextProcessingDocument: Codable, Equatable, Sendable {
  public let location: String

  public init(location: String) {
    self.location = location
  }
}

public struct SuggestedToolDocument: Codable, Equatable, Sendable {
  public let name: String
  public let access: String
  public let reason: String

  public init(name: String, access: String, reason: String) {
    self.name = name
    self.access = access
    self.reason = reason
  }
}

public struct ContextOmissionDocument: Codable, Equatable, Sendable {
  public let reason: String
  public let count: UInt64

  public init(reason: String, count: UInt64) {
    self.reason = reason
    self.count = count
  }
}

public struct AssemblyProvenanceDocument: Codable, Equatable, Sendable {
  public let engine: String
  public let engineVersion: String
  public let policyVersion: UInt32
  public let rankingVersion: UInt32

  public init(
    engine: String,
    engineVersion: String,
    policyVersion: UInt32,
    rankingVersion: UInt32
  ) {
    self.engine = engine
    self.engineVersion = engineVersion
    self.policyVersion = policyVersion
    self.rankingVersion = rankingVersion
  }
}
