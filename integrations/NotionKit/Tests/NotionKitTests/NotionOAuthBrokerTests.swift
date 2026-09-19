import Foundation
import Testing

@testable import NotionKit

@Test
func startsOAuthWithoutPuttingCredentialsInCallback() async throws {
  let transport = OAuthTransportProbe(
    responses: [
      OAuthResponse(
        statusCode: 200,
        body: """
          {
            "session_id":"session-1",
            "authorization_url":"https://api.notion.com/v1/oauth/authorize?state=server-state"
          }
          """
      )
    ]
  )
  let broker = try HTTPNotionOAuthBroker(
    baseURL: #require(URL(string: "https://broker.dayline.example/")),
    transport: transport
  )

  let session = try await broker.start(
    callbackURL: #require(URL(string: "dayline://oauth/notion"))
  )
  let request = try #require(await transport.requests.first)
  let body = try #require(request.httpBody)
  let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])

  #expect(session.id == "session-1")
  #expect(session.authorizationURL.scheme == "https")
  #expect(json == ["callback_url": "dayline://oauth/notion"])
  let bodyText = try #require(String(data: body, encoding: .utf8))
  #expect(!bodyText.contains("secret"))
}

@Test
func completesOAuthIntoVersionedConnectionMetadata() async throws {
  let transport = OAuthTransportProbe(
    responses: [
      OAuthResponse(
        statusCode: 200,
        body: """
          {
            "access_token":"access-secret",
            "refresh_token":"refresh-secret",
            "bot_id":"bot-1",
            "workspace_id":"workspace-1",
            "workspace_name":"Dayline workspace",
            "workspace_icon":null,
            "connection_id":"connection-1",
            "revocation_token":"revoke-secret"
          }
          """
      )
    ]
  )
  let broker = try HTTPNotionOAuthBroker(
    baseURL: #require(URL(string: "https://broker.dayline.example/")),
    transport: transport
  )

  let connection = try await broker.complete(sessionID: "session-1")

  #expect(connection.workspaceName == "Dayline workspace")
  #expect(connection.summary.authorization == .oauth)
  #expect(connection.accessToken == "access-secret")
  #expect(connection.refreshToken == "refresh-secret")
}

@Test
func revokesWithCapabilityAndIgnoresResponseBody() async throws {
  let transport = OAuthTransportProbe(
    responses: [OAuthResponse(statusCode: 204, body: "private-upstream-content")]
  )
  let broker = try HTTPNotionOAuthBroker(
    baseURL: #require(URL(string: "https://broker.dayline.example/")),
    transport: transport
  )

  try await broker.revoke(connectionID: "connection-1", revocationToken: "revoke-secret")
  let request = try #require(await transport.requests.first)
  let body = try #require(request.httpBody)
  let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])

  #expect(json["connection_id"] == "connection-1")
  #expect(json["revocation_token"] == "revoke-secret")
  #expect(
    request.url?.absoluteString
      == "https://broker.dayline.example/v1/notion/oauth/connections/revoke"
  )
}

@Test
func rejectsInsecureBrokerURLBeforeTransport() async throws {
  let transport = OAuthTransportProbe(responses: [])
  let broker = try HTTPNotionOAuthBroker(
    baseURL: #require(URL(string: "http://broker.dayline.example/")),
    transport: transport
  )

  await #expect(throws: NotionOAuthFailure.notConfigured) {
    try await broker.start(callbackURL: #require(URL(string: "dayline://oauth/notion")))
  }
  #expect(await transport.requests.isEmpty)
}

@Test
func callbackRequiresExactRouteSessionAndSuccessResult() throws {
  let expected = try #require(URL(string: "dayline://oauth/notion"))
  let valid = try #require(
    URL(string: "dayline://oauth/notion?session_id=session-1&result=success")
  )
  try NotionOAuthCallback.validate(valid, expected: expected, sessionID: "session-1")

  let wrongSession = try #require(
    URL(string: "dayline://oauth/notion?session_id=attacker&result=success")
  )
  #expect(throws: NotionOAuthFailure.invalidCallback) {
    try NotionOAuthCallback.validate(wrongSession, expected: expected, sessionID: "session-1")
  }
  let rejected = try #require(
    URL(string: "dayline://oauth/notion?session_id=session-1&result=denied")
  )
  #expect(throws: NotionOAuthFailure.invalidCallback) {
    try NotionOAuthCallback.validate(rejected, expected: expected, sessionID: "session-1")
  }
}

private struct OAuthResponse: Sendable {
  let statusCode: Int
  let body: String
}

private actor OAuthTransportProbe: NotionTransport {
  private var responses: [OAuthResponse]
  private(set) var requests: [URLRequest] = []

  init(responses: [OAuthResponse]) {
    self.responses = responses
  }

  func data(for request: URLRequest) throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    guard !responses.isEmpty else { throw NotionOAuthFailure.transportUnavailable }
    let response = responses.removeFirst()
    let url = try #require(request.url)
    let http = try #require(
      HTTPURLResponse(
        url: url,
        statusCode: response.statusCode,
        httpVersion: nil,
        headerFields: nil
      ))
    return (Data(response.body.utf8), http)
  }
}
