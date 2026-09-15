public struct ActionProposalDocument: Codable, Equatable, Sendable {
  public let schemaVersion: UInt32
  public let id: String
  public let proposedAt: String
  public let expiresAt: String?
  public let state: String
  public let sourceArtifactIds: [String]
  public let supportingEventIds: [String]
  public let tool: ProposedToolDocument
  public let argumentsSchema: VersionedIdentifierDocument
  public let arguments: [String: JSONValue]
  public let effect: String
  public let target: ActionTargetDocument
  public let risk: ActionRiskDocument
  public let permission: ActionPermissionDocument
  public let sensitivity: Sensitivity
  public let idempotencyKey: String
  public let rationale: String
  public let proposer: ActionProposerDocument

  public init(
    id: String,
    proposedAt: String,
    expiresAt: String?,
    sourceArtifactIds: [String],
    supportingEventIds: [String],
    tool: ProposedToolDocument,
    argumentsSchema: VersionedIdentifierDocument,
    arguments: [String: JSONValue],
    effect: String,
    target: ActionTargetDocument,
    risk: ActionRiskDocument,
    permission: ActionPermissionDocument,
    sensitivity: Sensitivity,
    idempotencyKey: String,
    rationale: String,
    proposer: ActionProposerDocument
  ) {
    schemaVersion = ContextCoreKit.schemaVersion
    self.id = id
    self.proposedAt = proposedAt
    self.expiresAt = expiresAt
    state = "proposed"
    self.sourceArtifactIds = sourceArtifactIds
    self.supportingEventIds = supportingEventIds
    self.tool = tool
    self.argumentsSchema = argumentsSchema
    self.arguments = arguments
    self.effect = effect
    self.target = target
    self.risk = risk
    self.permission = permission
    self.sensitivity = sensitivity
    self.idempotencyKey = idempotencyKey
    self.rationale = rationale
    self.proposer = proposer
  }

  public func validateVersion() throws {
    try ContractCodec.validate(schemaVersion: schemaVersion)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(schemaVersion, forKey: .schemaVersion)
    try container.encode(id, forKey: .id)
    try container.encode(proposedAt, forKey: .proposedAt)
    try container.encode(expiresAt, forKey: .expiresAt)
    try container.encode(state, forKey: .state)
    try container.encode(sourceArtifactIds, forKey: .sourceArtifactIds)
    try container.encode(supportingEventIds, forKey: .supportingEventIds)
    try container.encode(tool, forKey: .tool)
    try container.encode(argumentsSchema, forKey: .argumentsSchema)
    try container.encode(arguments, forKey: .arguments)
    try container.encode(effect, forKey: .effect)
    try container.encode(target, forKey: .target)
    try container.encode(risk, forKey: .risk)
    try container.encode(permission, forKey: .permission)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(idempotencyKey, forKey: .idempotencyKey)
    try container.encode(rationale, forKey: .rationale)
    try container.encode(proposer, forKey: .proposer)
  }
}

public struct ProposedToolDocument: Codable, Equatable, Sendable {
  public let integration: String
  public let name: String
  public let operation: String

  public init(integration: String, name: String, operation: String) {
    self.integration = integration
    self.name = name
    self.operation = operation
  }
}

public struct ActionTargetDocument: Codable, Equatable, Sendable {
  public let type: String
  public let identifier: String
  public let displayName: String?

  public init(type: String, identifier: String, displayName: String?) {
    self.type = type
    self.identifier = identifier
    self.displayName = displayName
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encode(identifier, forKey: .identifier)
    try container.encode(displayName, forKey: .displayName)
  }
}

public struct ActionRiskDocument: Codable, Equatable, Sendable {
  public let level: String
  public let destructive: Bool
  public let reasons: [String]

  public init(level: String, destructive: Bool, reasons: [String]) {
    self.level = level
    self.destructive = destructive
    self.reasons = reasons
  }
}

public struct ActionPermissionDocument: Codable, Equatable, Sendable {
  public let requiredScopes: [String]
  public let confirmation: String

  public init(requiredScopes: [String], confirmation: String) {
    self.requiredScopes = requiredScopes
    self.confirmation = confirmation
  }
}

public enum ActionProposerDocument: Codable, Equatable, Sendable {
  case model(ModelActionProposerDocument)
  case rule(RuleActionProposerDocument)

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: ProposerCodingKeys.self)
    switch try container.decode(String.self, forKey: .type) {
    case "model": self = .model(try ModelActionProposerDocument(from: decoder))
    case "rule": self = .rule(try RuleActionProposerDocument(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "Unsupported proposer type"
      )
    }
  }

  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .model(let value): try value.encode(to: encoder)
    case .rule(let value): try value.encode(to: encoder)
    }
  }
}

public struct ModelActionProposerDocument: Codable, Equatable, Sendable {
  public let type: String
  public let runtime: String
  public let model: String
  public let promptId: String
  public let promptVersion: UInt32
  public let runId: String

  public init(
    runtime: String, model: String, promptId: String, promptVersion: UInt32, runId: String
  ) {
    type = "model"
    self.runtime = runtime
    self.model = model
    self.promptId = promptId
    self.promptVersion = promptVersion
    self.runId = runId
  }
}

public struct RuleActionProposerDocument: Codable, Equatable, Sendable {
  public let type: String
  public let ruleId: String
  public let ruleVersion: UInt32

  public init(ruleId: String, ruleVersion: UInt32) {
    type = "rule"
    self.ruleId = ruleId
    self.ruleVersion = ruleVersion
  }
}

private enum ProposerCodingKeys: String, CodingKey {
  case type
}
