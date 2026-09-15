import ContextCoreKit
import Foundation

public enum ExternalActionDecision: String, Equatable, Sendable {
  case allow
  case ask
  case deny
}

public struct ExternalActionEvaluation: Equatable, Sendable {
  public let decision: ExternalActionDecision
  public let reason: String

  public init(decision: ExternalActionDecision, reason: String) {
    self.decision = decision
    self.reason = reason
  }
}

public protocol ExternalActionPolicyEvaluating: Sendable {
  func evaluate(_ proposal: ActionProposalDocument) throws -> ExternalActionEvaluation
}

public struct ExternalOutputReceipt: Equatable, Sendable {
  public let remoteID: String
  public let remoteURL: URL?

  public init(remoteID: String, remoteURL: URL?) {
    self.remoteID = remoteID
    self.remoteURL = remoteURL
  }
}

public protocol NotionOutputWriting: Sendable {
  func write(_ approvedProposal: ActionProposalDocument) async throws -> ExternalOutputReceipt
}
