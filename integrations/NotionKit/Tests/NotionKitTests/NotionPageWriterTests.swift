import ContextCoreKit
import Foundation
import Testing

@testable import NotionKit

@Test
func createsPageWithPinnedVersionAndApprovedContent() async throws {
  let transport = NotionTransportProbe(
    statusCode: 200,
    response: Data(
      #"{"id":"created-page","url":"https://app.notion.com/p/created-page"}"#.utf8
    )
  )
  let writer = NotionPageWriter(
    credentials: FixedNotionCredentials(token: "unit-test-token"),
    transport: transport
  )

  let receipt = try await writer.write(notionProposal())
  let request = try #require(await transport.request)
  let body = try #require(request.httpBody)
  let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])

  #expect(receipt.remoteID == "created-page")
  #expect(request.value(forHTTPHeaderField: "Notion-Version") == "2026-03-11")
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer unit-test-token")
  #expect(json["markdown"] as? String == "Summary")
}

@Test
func rejectsUnapprovedShapeBeforeReadingCredentialsOrSending() async {
  let credentials = NotionCredentialProbe()
  let transport = NotionTransportProbe(statusCode: 200, response: Data())
  let writer = NotionPageWriter(credentials: credentials, transport: transport)
  let invalid = notionProposal(confirmation: "policy_decides")

  await #expect(throws: NotionOutputFailure.invalidProposal) {
    try await writer.write(invalid)
  }
  #expect(await credentials.readCount == 0)
  #expect(await transport.request == nil)
}

@Test
func mapsRemoteFailuresWithoutReturningResponseContent() async {
  let writer = NotionPageWriter(
    credentials: FixedNotionCredentials(token: "unit-test-token"),
    transport: NotionTransportProbe(statusCode: 403, response: Data("private".utf8))
  )

  await #expect(throws: NotionOutputFailure.forbidden) {
    try await writer.write(notionProposal())
  }
}

private struct FixedNotionCredentials: NotionCredentialProviding {
  let token: String
  func accessToken() -> String { token }
}

private actor NotionCredentialProbe: NotionCredentialProviding {
  private(set) var readCount = 0
  func accessToken() -> String {
    readCount += 1
    return "unused"
  }
}

private actor NotionTransportProbe: NotionTransport {
  private let statusCode: Int
  private let response: Data
  private(set) var request: URLRequest?

  init(statusCode: Int, response: Data) {
    self.statusCode = statusCode
    self.response = response
  }

  func data(for request: URLRequest) throws -> (Data, HTTPURLResponse) {
    self.request = request
    let url = try #require(request.url)
    let response = try #require(
      HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
      ))
    return (self.response, response)
  }
}

private func notionProposal(
  confirmation: String = "required"
) -> ActionProposalDocument {
  ActionProposalDocument(
    id: "018f6ea2-8f44-7f00-8000-000000000951",
    proposedAt: "2026-09-15T01:00:00Z",
    expiresAt: "2026-09-15T02:00:00Z",
    sourceArtifactIds: ["018f6ea2-8f44-7f00-8000-000000000952"],
    supportingEventIds: [],
    tool: ProposedToolDocument(integration: "notion", name: "notion.page", operation: "create"),
    argumentsSchema: VersionedIdentifierDocument(id: "notion.page.create", version: 1),
    arguments: [
      "parent_page_id": .string("parent-page"),
      "title": .string("Daily Summary"),
      "markdown": .string("Summary"),
    ],
    effect: "create",
    target: ActionTargetDocument(type: "notion_page", identifier: "parent-page", displayName: nil),
    risk: ActionRiskDocument(level: "medium", destructive: false, reasons: ["External write"]),
    permission: ActionPermissionDocument(
      requiredScopes: ["notion.write"],
      confirmation: confirmation
    ),
    sensitivity: .sensitive,
    idempotencyKey: "artifact:notion",
    rationale: "Export selected artifact",
    proposer: .rule(RuleActionProposerDocument(ruleId: "notion-export", ruleVersion: 1))
  )
}
