import ContextCoreKit
import Foundation

public enum NotionExportFailure: Error, Equatable, Sendable {
  case invalidParent
  case policyDenied
  case confirmationRequired
  case outputUnavailable
}

public struct PreparedNotionExport: Equatable, Sendable {
  public let proposal: ActionProposalDocument
  public let evaluation: ExternalActionEvaluation

  public init(proposal: ActionProposalDocument, evaluation: ExternalActionEvaluation) {
    self.proposal = proposal
    self.evaluation = evaluation
  }
}

public struct NotionExportService: Sendable {
  private let policy: any ExternalActionPolicyEvaluating
  private let writer: any NotionOutputWriting
  private let now: @Sendable () -> Date
  private let proposalID: @Sendable () -> String

  public init(
    policy: any ExternalActionPolicyEvaluating,
    writer: any NotionOutputWriting,
    now: @escaping @Sendable () -> Date = Date.init,
    proposalID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
  ) {
    self.policy = policy
    self.writer = writer
    self.now = now
    self.proposalID = proposalID
  }

  public func prepare(
    artifact: SemanticArtifactDocument,
    parentPageID: String,
    title: String
  ) throws -> PreparedNotionExport {
    let parent = parentPageID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !parent.isEmpty else { throw NotionExportFailure.invalidParent }
    let timestamp = now()
    let proposal = makeProposal(
      artifact: artifact,
      parentPageID: parent,
      title: title,
      timestamp: timestamp
    )
    let evaluation = try policy.evaluate(proposal)
    guard evaluation.decision != .deny else { throw NotionExportFailure.policyDenied }
    return PreparedNotionExport(proposal: proposal, evaluation: evaluation)
  }

  private func makeProposal(
    artifact: SemanticArtifactDocument,
    parentPageID: String,
    title: String,
    timestamp: Date
  ) -> ActionProposalDocument {
    let proposal = ActionProposalDocument(
      id: proposalID(),
      proposedAt: ISO8601DateFormatter().string(from: timestamp),
      expiresAt: ISO8601DateFormatter().string(from: timestamp.addingTimeInterval(3_600)),
      sourceArtifactIds: [artifact.id],
      supportingEventIds: artifact.sourceEventIds,
      tool: ProposedToolDocument(
        integration: "notion",
        name: "notion.page",
        operation: "create"
      ),
      argumentsSchema: VersionedIdentifierDocument(id: "notion.page.create", version: 1),
      arguments: [
        "parent_page_id": .string(parentPageID),
        "title": .string(title),
        "markdown": .string(NotionArtifactRenderer.markdown(for: artifact)),
      ],
      effect: "create",
      target: ActionTargetDocument(
        type: "notion_page",
        identifier: parentPageID,
        displayName: "Configured Notion parent"
      ),
      risk: ActionRiskDocument(
        level: "medium",
        destructive: false,
        reasons: ["Writes selected semantic content to an external service."]
      ),
      permission: ActionPermissionDocument(
        requiredScopes: ["notion.write"],
        confirmation: "required"
      ),
      sensitivity: artifact.sensitivity,
      idempotencyKey: "artifact:\(artifact.id):notion",
      rationale: "Export the user-selected Dayline artifact to Notion.",
      proposer: .model(
        ModelActionProposerDocument(
          runtime: artifact.generation.runtime,
          model: artifact.generation.model,
          promptId: artifact.generation.promptId,
          promptVersion: artifact.generation.promptVersion,
          runId: artifact.generation.runId
        )
      )
    )
    return proposal
  }

  public func execute(
    _ prepared: PreparedNotionExport,
    userConfirmed: Bool
  ) async throws -> ExternalOutputReceipt {
    let evaluation = try policy.evaluate(prepared.proposal)
    guard evaluation.decision != .deny else { throw NotionExportFailure.policyDenied }
    guard evaluation.decision != .ask || userConfirmed else {
      throw NotionExportFailure.confirmationRequired
    }
    do {
      return try await writer.write(prepared.proposal)
    } catch let error as NotionExportFailure {
      throw error
    } catch {
      throw NotionExportFailure.outputUnavailable
    }
  }
}
