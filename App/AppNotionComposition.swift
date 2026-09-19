import Foundation
import NotionKit

extension AppEnvironment {
  static func makeNotionConnection(
    processInfo: ProcessInfo,
    credentials: any NotionCredentialStoring
  ) -> NotionConnectionModel {
    let callbackURL = URL(string: "dayline://oauth/notion") ?? URL(fileURLWithPath: "/")
    if processInfo.arguments.contains("--ui-testing") {
      return NotionConnectionModel(
        broker: DeterministicNotionOAuthBroker(),
        credentials: credentials,
        webAuthentication: DeterministicWebAuthentication(),
        destinationListing: DeterministicNotionDestinationListing(),
        callbackURL: callbackURL
      )
    }
    let broker: any NotionOAuthBrokering
    if let rawURL = Bundle.main.object(
      forInfoDictionaryKey: "DAYLINE_NOTION_OAUTH_BROKER_URL"
    ) as? String,
      let baseURL = URL(string: rawURL),
      baseURL.scheme == "https"
    {
      broker = HTTPNotionOAuthBroker(baseURL: baseURL)
    } else {
      broker = UnavailableNotionOAuthBroker()
    }
    return NotionConnectionModel(
      broker: broker,
      credentials: credentials,
      webAuthentication: AppWebAuthenticationSession(),
      destinationListing: NotionPageDirectory(credentials: credentials),
      callbackURL: callbackURL
    )
  }
}

actor InMemoryNotionCredentialStore: NotionCredentialStoring {
  private var token: String?
  private var storedConnection: NotionConnection?

  func accessToken() throws -> String {
    if let storedConnection { return storedConnection.accessToken }
    guard let token else { throw NotionCredentialFailure.unavailable }
    return token
  }

  func connection() -> NotionConnection? {
    storedConnection
  }

  func connectionSummary() throws -> NotionConnectionSummary {
    if let storedConnection { return storedConnection.summary }
    guard token != nil else { throw NotionCredentialFailure.unavailable }
    return NotionConnectionSummary(
      workspaceID: nil,
      workspaceName: "開発用の手動接続",
      workspaceIcon: nil,
      authorization: .manualDevelopment
    )
  }

  func save(connection: NotionConnection) {
    storedConnection = connection
    token = nil
  }

  func save(accessToken: String) {
    token = accessToken
  }

  func remove() {
    token = nil
    storedConnection = nil
  }
}

private struct DeterministicNotionOAuthBroker: NotionOAuthBrokering {
  func start(callbackURL _: URL) throws -> NotionOAuthSession {
    guard let url = URL(string: "https://example.invalid/notion-authorize") else {
      throw NotionOAuthFailure.invalidResponse
    }
    return NotionOAuthSession(id: "ui-test-session", authorizationURL: url)
  }

  func complete(sessionID: String) throws -> NotionConnection {
    guard sessionID == "ui-test-session" else { throw NotionOAuthFailure.invalidCallback }
    return NotionConnection(
      accessToken: "ui-test-token",
      refreshToken: "ui-test-refresh-token",
      botID: "ui-test-bot",
      workspaceID: "ui-test-workspace",
      workspaceName: "UI Test Workspace",
      workspaceIcon: nil,
      connectionID: "ui-test-connection",
      revocationToken: "ui-test-revocation-token"
    )
  }

  func revoke(connectionID: String, revocationToken: String) throws {
    guard connectionID == "ui-test-connection", revocationToken == "ui-test-revocation-token"
    else { throw NotionOAuthFailure.rejected }
  }
}

private struct DeterministicNotionDestinationListing: NotionDestinationListing {
  func listDestinations() -> [NotionDestination] {
    [
      NotionDestination(id: "parent-page", title: "UI Test Destination", url: nil)
    ]
  }
}

@MainActor
private struct DeterministicWebAuthentication: AppWebAuthenticating {
  func authenticate(at _: URL, callbackScheme _: String) throws -> URL {
    guard let callback = URL(
      string: "dayline://oauth/notion?session_id=ui-test-session&result=success"
    ) else {
      throw AppWebAuthenticationFailure.missingCallback
    }
    return callback
  }
}
