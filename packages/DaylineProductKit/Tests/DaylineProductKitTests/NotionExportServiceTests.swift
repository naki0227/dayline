import AppleIntelligenceKit
import ContextCoreKit
import Foundation
import Testing

@testable import DaylineProductKit

@Test
func preparesTraceableNotionProposalAndRequiresConfirmation() async throws {
  let writer = NotionWriterProbe()
  let service = NotionExportService(
    policy: FixedActionPolicy(decision: .ask),
    writer: writer,
    now: { Date(timeIntervalSince1970: 1_789_344_000) },
    proposalID: { "018f6ea2-8f44-7f00-8000-000000000941" }
  )
  let prepared = try service.prepare(
    artifact: notionArtifact(),
    parentPageID: "parent-page",
    title: "2026-09-15 Daily Summary"
  )

  #expect(prepared.proposal.sourceArtifactIds == [notionArtifact().id])
  #expect(prepared.proposal.supportingEventIds == notionArtifact().sourceEventIds)
  #expect(prepared.proposal.arguments["markdown"] == .string("Summary\n\n---\nDayline evidence: 1"))
  await #expect(throws: NotionExportFailure.confirmationRequired) {
    try await service.execute(prepared, userConfirmed: false)
  }
  #expect(await writer.proposals.isEmpty)

  let receipt = try await service.execute(prepared, userConfirmed: true)
  #expect(receipt.remoteID == "notion-page")
  #expect(await writer.proposals == [prepared.proposal])
}

@Test
func deniedNotionProposalNeverReachesTheWriter() async throws {
  let writer = NotionWriterProbe()
  let service = NotionExportService(
    policy: FixedActionPolicy(decision: .deny),
    writer: writer
  )

  #expect(throws: NotionExportFailure.policyDenied) {
    try service.prepare(artifact: notionArtifact(), parentPageID: "parent", title: "Summary")
  }
  #expect(await writer.proposals.isEmpty)
}

private struct FixedActionPolicy: ExternalActionPolicyEvaluating {
  let decision: ExternalActionDecision

  func evaluate(_: ActionProposalDocument) -> ExternalActionEvaluation {
    ExternalActionEvaluation(decision: decision, reason: "test_policy")
  }
}

private actor NotionWriterProbe: NotionOutputWriting {
  private(set) var proposals: [ActionProposalDocument] = []

  func write(_ approvedProposal: ActionProposalDocument) -> ExternalOutputReceipt {
    proposals.append(approvedProposal)
    return ExternalOutputReceipt(remoteID: "notion-page", remoteURL: nil)
  }
}

private func notionArtifact() -> SemanticArtifactDocument {
  SemanticArtifactDocument(
    id: "018f6ea2-8f44-7f00-8000-000000000942",
    createdAt: "2026-09-15T01:00:00Z",
    dayId: DayIDDocument(localDate: "2026-09-15", timezone: "Asia/Tokyo"),
    sessionId: nil,
    kind: "summary",
    content: SemanticContentDocument(text: "Summary", attributes: ["language": "en"]),
    sourceEventIds: ["018f6ea2-8f44-7f00-8000-000000000943"],
    sourceArtifactIds: [],
    confidence: nil,
    sensitivity: .sensitive,
    retention: RetentionDocument(type: "days", days: 30),
    generation: GenerationProvenanceDocument(
      runtime: "stub",
      model: "deterministic-stub",
      promptId: "daily-summary",
      promptVersion: 1,
      runId: "018f6ea2-8f44-7f00-8000-000000000944",
      generatedAt: "2026-09-15T01:00:00Z"
    )
  )
}
