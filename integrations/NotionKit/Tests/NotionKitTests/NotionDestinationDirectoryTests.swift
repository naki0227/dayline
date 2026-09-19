import Foundation
import Testing

@testable import NotionKit

@Test
func listsSharedNotionPagesWithoutExposingTokenInBody() async throws {
  let transport = DestinationTransportProbe(
    statusCode: 200,
    body: """
      {
        "results": [
          {
            "id": "page-b",
            "url": "https://notion.so/page-b",
            "properties": {
              "Name": {
                "type": "title",
                "title": [{"plain_text": "Projects"}]
              }
            }
          },
          {
            "id": "page-a",
            "url": null,
            "properties": {
              "title": {
                "type": "title",
                "title": [{"plain_text": "Daily"}]
              }
            }
          }
        ]
      }
      """
  )
  let directory = NotionPageDirectory(
    credentials: DestinationCredentials(),
    transport: transport
  )

  let destinations = try await directory.listDestinations()
  let request = try #require(await transport.request)

  #expect(destinations.map(\.title) == ["Daily", "Projects"])
  #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-secret")
  #expect(request.value(forHTTPHeaderField: "Notion-Version") == "2026-03-11")
  let requestBody = try #require(request.httpBody)
  let bodyText = try #require(String(data: requestBody, encoding: .utf8))
  #expect(!bodyText.contains("access-secret"))
}

@Test
func mapsDestinationAuthorizationFailureWithoutResponseContent() async {
  let directory = NotionPageDirectory(
    credentials: DestinationCredentials(),
    transport: DestinationTransportProbe(statusCode: 403, body: "private")
  )

  await #expect(throws: NotionDestinationFailure.unauthorized) {
    try await directory.listDestinations()
  }
}

private struct DestinationCredentials: NotionCredentialProviding {
  func accessToken() -> String { "access-secret" }
}

private actor DestinationTransportProbe: NotionTransport {
  private let statusCode: Int
  private let body: String
  private(set) var request: URLRequest?

  init(statusCode: Int, body: String) {
    self.statusCode = statusCode
    self.body = body
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
    return (Data(body.utf8), response)
  }
}
