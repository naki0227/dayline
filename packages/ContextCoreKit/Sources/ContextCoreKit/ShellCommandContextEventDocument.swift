public struct ShellCommandContextEventDocument: Codable, Equatable, Sendable {
  public let schemaVersion: UInt32
  public let id: String
  public let occurredAt: String
  public let dayId: DayIDDocument
  public let sessionId: String?
  public let source: ContextSourceDocument
  public let kind: String
  public let payload: ShellCommandPayloadDocument
  public let metadata: [String: String]
  public let sensitivity: Sensitivity
  public let retention: RetentionDocument
  public let provenance: EventProvenanceDocument

  public init(
    id: String, occurredAt: String, dayId: DayIDDocument,
    command: String, cwd: String, exitCode: Int?, durationMilliseconds: UInt64?,
    metadata: [String: String], retention: RetentionDocument,
    provenance: EventProvenanceDocument
  ) {
    schemaVersion = ContextCoreKit.schemaVersion
    self.id = id
    self.occurredAt = occurredAt
    self.dayId = dayId
    sessionId = nil
    source = ContextSourceDocument(type: "shell")
    kind = "command"
    payload = ShellCommandPayloadDocument(
      command: command, cwd: cwd, exitCode: exitCode,
      durationMilliseconds: durationMilliseconds
    )
    self.metadata = metadata
    sensitivity = .sensitive
    self.retention = retention
    self.provenance = provenance
  }

  public func validateVersion() throws {
    try ContractCodec.validate(schemaVersion: schemaVersion)
  }
}

public struct ShellCommandPayloadDocument: Codable, Equatable, Sendable {
  public let type = "shell_command"
  public let content: ShellCommandContentDocument

  public init(command: String, cwd: String, exitCode: Int?, durationMilliseconds: UInt64?) {
    content = ShellCommandContentDocument(
      command: command, cwd: cwd, exitCode: exitCode,
      durationMilliseconds: durationMilliseconds
    )
  }

  private enum CodingKeys: String, CodingKey { case type, content }
}

public struct ShellCommandContentDocument: Codable, Equatable, Sendable {
  public let command: String
  public let cwd: String
  public let exitCode: Int?
  public let durationMilliseconds: UInt64?

  public init(command: String, cwd: String, exitCode: Int?, durationMilliseconds: UInt64?) {
    self.command = command
    self.cwd = cwd
    self.exitCode = exitCode
    self.durationMilliseconds = durationMilliseconds
  }

  private enum CodingKeys: String, CodingKey {
    case command, cwd
    case exitCode = "exit_code"
    case durationMilliseconds = "duration_ms"
  }
}
