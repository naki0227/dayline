import Foundation

public enum NotionOAuthFailure: Error, Equatable, Sendable {
  case notConfigured
  case invalidCallback
  case rejected
  case transportUnavailable
  case invalidResponse
}

public struct NotionOAuthSession: Equatable, Sendable {
  public let id: String
  public let authorizationURL: URL

  public init(id: String, authorizationURL: URL) {
    self.id = id
    self.authorizationURL = authorizationURL
  }
}

public enum NotionOAuthCallback {
  public static func validate(_ callback: URL, expected: URL, sessionID: String) throws {
    guard
      callback.scheme == expected.scheme,
      callback.host == expected.host,
      callback.path == expected.path,
      let components = URLComponents(url: callback, resolvingAgainstBaseURL: false),
      components.queryItems?.first(where: { $0.name == "session_id" })?.value == sessionID,
      components.queryItems?.first(where: { $0.name == "result" })?.value == "success"
    else { throw NotionOAuthFailure.invalidCallback }
  }
}

public protocol NotionOAuthBrokering: Sendable {
  func start(callbackURL: URL) async throws -> NotionOAuthSession
  func complete(sessionID: String) async throws -> NotionConnection
  func revoke(connectionID: String, revocationToken: String) async throws
}

public struct UnavailableNotionOAuthBroker: NotionOAuthBrokering, Sendable {
  public init() {}

  public func start(callbackURL _: URL) throws -> NotionOAuthSession {
    throw NotionOAuthFailure.notConfigured
  }

  public func complete(sessionID _: String) throws -> NotionConnection {
    throw NotionOAuthFailure.notConfigured
  }

  public func revoke(connectionID _: String, revocationToken _: String) throws {
    throw NotionOAuthFailure.notConfigured
  }
}

public struct HTTPNotionOAuthBroker: NotionOAuthBrokering, Sendable {
  private let baseURL: URL
  private let transport: any NotionTransport

  public init(baseURL: URL, transport: any NotionTransport = URLSessionNotionTransport()) {
    self.baseURL = baseURL
    self.transport = transport
  }

  public func start(callbackURL: URL) async throws -> NotionOAuthSession {
    let request = try makeRequest(
      path: "v1/notion/oauth/sessions",
      body: StartRequest(callbackURL: callbackURL.absoluteString)
    )
    let response: StartResponse = try await send(request, expecting: 200)
    guard
      !response.sessionID.isEmpty,
      let authorizationURL = URL(string: response.authorizationURL),
      authorizationURL.scheme == "https"
    else { throw NotionOAuthFailure.invalidResponse }
    return NotionOAuthSession(id: response.sessionID, authorizationURL: authorizationURL)
  }

  public func complete(sessionID: String) async throws -> NotionConnection {
    guard !sessionID.isEmpty else { throw NotionOAuthFailure.invalidCallback }
    let request = try makeRequest(
      path: "v1/notion/oauth/sessions/complete",
      body: CompleteRequest(sessionID: sessionID)
    )
    let response: CompleteResponse = try await send(request, expecting: 200)
    guard
      !response.accessToken.isEmpty,
      !response.botID.isEmpty,
      !response.workspaceID.isEmpty,
      !response.workspaceName.isEmpty,
      !response.connectionID.isEmpty,
      !response.revocationToken.isEmpty
    else { throw NotionOAuthFailure.invalidResponse }
    return NotionConnection(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      botID: response.botID,
      workspaceID: response.workspaceID,
      workspaceName: response.workspaceName,
      workspaceIcon: response.workspaceIcon,
      connectionID: response.connectionID,
      revocationToken: response.revocationToken
    )
  }

  public func revoke(connectionID: String, revocationToken: String) async throws {
    guard !connectionID.isEmpty, !revocationToken.isEmpty else {
      throw NotionOAuthFailure.invalidResponse
    }
    let request = try makeRequest(
      path: "v1/notion/oauth/connections/revoke",
      body: RevokeRequest(connectionID: connectionID, revocationToken: revocationToken)
    )
    let (_, response) = try await perform(request)
    guard response.statusCode == 204 else { throw map(statusCode: response.statusCode) }
  }

  private func makeRequest<Body: Encodable>(path: String, body: Body) throws -> URLRequest {
    guard baseURL.scheme == "https", let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
    else { throw NotionOAuthFailure.notConfigured }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    do {
      request.httpBody = try JSONEncoder().encode(body)
    } catch {
      throw NotionOAuthFailure.invalidResponse
    }
    return request
  }

  private func send<Response: Decodable>(
    _ request: URLRequest,
    expecting statusCode: Int
  ) async throws -> Response {
    let (data, response) = try await perform(request)
    guard response.statusCode == statusCode else { throw map(statusCode: response.statusCode) }
    do {
      return try JSONDecoder().decode(Response.self, from: data)
    } catch {
      throw NotionOAuthFailure.invalidResponse
    }
  }

  private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    do {
      return try await transport.data(for: request)
    } catch let failure as NotionOAuthFailure {
      throw failure
    } catch {
      throw NotionOAuthFailure.transportUnavailable
    }
  }

  private func map(statusCode: Int) -> NotionOAuthFailure {
    switch statusCode {
    case 400, 401, 403, 404, 409, 410, 422: .rejected
    default: .transportUnavailable
    }
  }
}

private struct StartRequest: Encodable {
  let callbackURL: String

  enum CodingKeys: String, CodingKey {
    case callbackURL = "callback_url"
  }
}

private struct StartResponse: Decodable {
  let sessionID: String
  let authorizationURL: String

  enum CodingKeys: String, CodingKey {
    case sessionID = "session_id"
    case authorizationURL = "authorization_url"
  }
}

private struct CompleteRequest: Encodable {
  let sessionID: String

  enum CodingKeys: String, CodingKey {
    case sessionID = "session_id"
  }
}

private struct CompleteResponse: Decodable {
  let accessToken: String
  let refreshToken: String?
  let botID: String
  let workspaceID: String
  let workspaceName: String
  let workspaceIcon: String?
  let connectionID: String
  let revocationToken: String

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    case botID = "bot_id"
    case workspaceID = "workspace_id"
    case workspaceName = "workspace_name"
    case workspaceIcon = "workspace_icon"
    case connectionID = "connection_id"
    case revocationToken = "revocation_token"
  }
}

private struct RevokeRequest: Encodable {
  let connectionID: String
  let revocationToken: String

  enum CodingKeys: String, CodingKey {
    case connectionID = "connection_id"
    case revocationToken = "revocation_token"
  }
}
