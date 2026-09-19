import Foundation
import Security

public enum NotionCredentialFailure: Error, Equatable, Sendable {
  case unavailable
  case invalidEncoding
  case keychainFailure
}

public enum NotionAuthorizationKind: String, Codable, Equatable, Sendable {
  case oauth
  case manualDevelopment
}

public struct NotionConnectionSummary: Equatable, Sendable {
  public let workspaceID: String?
  public let workspaceName: String
  public let workspaceIcon: String?
  public let authorization: NotionAuthorizationKind

  public init(
    workspaceID: String?,
    workspaceName: String,
    workspaceIcon: String?,
    authorization: NotionAuthorizationKind
  ) {
    self.workspaceID = workspaceID
    self.workspaceName = workspaceName
    self.workspaceIcon = workspaceIcon
    self.authorization = authorization
  }
}

public struct NotionConnection: Codable, Equatable, Sendable {
  public let accessToken: String
  public let refreshToken: String?
  public let botID: String
  public let workspaceID: String
  public let workspaceName: String
  public let workspaceIcon: String?
  public let connectionID: String
  public let revocationToken: String

  public init(
    accessToken: String,
    refreshToken: String?,
    botID: String,
    workspaceID: String,
    workspaceName: String,
    workspaceIcon: String?,
    connectionID: String,
    revocationToken: String
  ) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.botID = botID
    self.workspaceID = workspaceID
    self.workspaceName = workspaceName
    self.workspaceIcon = workspaceIcon
    self.connectionID = connectionID
    self.revocationToken = revocationToken
  }

  public var summary: NotionConnectionSummary {
    NotionConnectionSummary(
      workspaceID: workspaceID,
      workspaceName: workspaceName,
      workspaceIcon: workspaceIcon,
      authorization: .oauth
    )
  }
}

public protocol NotionCredentialProviding: Sendable {
  func accessToken() async throws -> String
}

public protocol NotionCredentialStoring: NotionCredentialProviding {
  func connection() async throws -> NotionConnection?
  func connectionSummary() async throws -> NotionConnectionSummary
  func save(connection: NotionConnection) async throws
  func save(accessToken: String) async throws
  func remove() async throws
}

public actor KeychainNotionCredentialStore: NotionCredentialStoring {
  private let service: String
  private let connectionAccount = "oauth-connection-v1"
  private let legacyAccount = "access-token"

  public init(service: String = "com.dayline.notion") {
    self.service = service
  }

  public func accessToken() throws -> String {
    if let connection = try connection() { return connection.accessToken }
    return try legacyAccessToken()
  }

  public func connection() throws -> NotionConnection? {
    guard let data = try read(account: connectionAccount) else { return nil }
    do {
      return try JSONDecoder().decode(NotionConnection.self, from: data)
    } catch {
      throw NotionCredentialFailure.invalidEncoding
    }
  }

  public func connectionSummary() throws -> NotionConnectionSummary {
    if let connection = try connection() { return connection.summary }
    _ = try legacyAccessToken()
    return NotionConnectionSummary(
      workspaceID: nil,
      workspaceName: "開発用の手動接続",
      workspaceIcon: nil,
      authorization: .manualDevelopment
    )
  }

  public func save(connection: NotionConnection) throws {
    guard
      !connection.accessToken.isEmpty,
      !connection.botID.isEmpty,
      !connection.workspaceID.isEmpty,
      !connection.workspaceName.isEmpty,
      !connection.connectionID.isEmpty,
      !connection.revocationToken.isEmpty
    else { throw NotionCredentialFailure.invalidEncoding }
    let data: Data
    do {
      data = try JSONEncoder().encode(connection)
    } catch {
      throw NotionCredentialFailure.invalidEncoding
    }
    try write(data, account: connectionAccount)
    try delete(account: legacyAccount)
  }

  public func save(accessToken: String) throws {
    let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty, let data = token.data(using: .utf8) else {
      throw NotionCredentialFailure.invalidEncoding
    }
    try write(data, account: legacyAccount)
  }

  public func remove() throws {
    try delete(account: connectionAccount)
    try delete(account: legacyAccount)
  }

  private func legacyAccessToken() throws -> String {
    guard let data = try read(account: legacyAccount) else {
      throw NotionCredentialFailure.unavailable
    }
    guard let token = String(data: data, encoding: .utf8), !token.isEmpty else {
      throw NotionCredentialFailure.invalidEncoding
    }
    return token
  }

  private func read(account: String) throws -> Data? {
    var query = baseQuery(account: account)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else {
      throw NotionCredentialFailure.keychainFailure
    }
    return data
  }

  private func write(_ data: Data, account: String) throws {
    let query = baseQuery(account: account)
    let attributes: [CFString: Any] = [
      kSecValueData: data,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else {
      throw NotionCredentialFailure.keychainFailure
    }
    var add = query
    add[kSecValueData] = data
    add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else {
      throw NotionCredentialFailure.keychainFailure
    }
  }

  private func delete(account: String) throws {
    let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw NotionCredentialFailure.keychainFailure
    }
  }

  private func baseQuery(account: String) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
      kSecAttrSynchronizable: false,
    ]
  }
}
