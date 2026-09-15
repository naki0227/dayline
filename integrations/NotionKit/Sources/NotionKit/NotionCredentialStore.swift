import Foundation
import Security

public enum NotionCredentialFailure: Error, Equatable, Sendable {
  case unavailable
  case invalidEncoding
  case keychainFailure
}

public protocol NotionCredentialProviding: Sendable {
  func accessToken() async throws -> String
}

public protocol NotionCredentialStoring: NotionCredentialProviding {
  func save(accessToken: String) async throws
  func remove() async throws
}

public actor KeychainNotionCredentialStore: NotionCredentialStoring {
  private let service: String
  private let account = "access-token"

  public init(service: String = "com.dayline.notion") {
    self.service = service
  }

  public func accessToken() throws -> String {
    var item: CFTypeRef?
    let status = SecItemCopyMatching(readQuery, &item)
    guard status != errSecItemNotFound else { throw NotionCredentialFailure.unavailable }
    guard status == errSecSuccess else { throw NotionCredentialFailure.keychainFailure }
    guard let data = item as? Data, let token = String(data: data, encoding: .utf8), !token.isEmpty
    else { throw NotionCredentialFailure.invalidEncoding }
    return token
  }

  public func save(accessToken: String) throws {
    let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty, let data = token.data(using: .utf8) else {
      throw NotionCredentialFailure.invalidEncoding
    }
    let attributes: [CFString: Any] = [
      kSecValueData: data,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else {
      throw NotionCredentialFailure.keychainFailure
    }
    var add = baseQuery
    add[kSecValueData] = data
    add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else {
      throw NotionCredentialFailure.keychainFailure
    }
  }

  public func remove() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw NotionCredentialFailure.keychainFailure
    }
  }

  private var baseQuery: [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
      kSecAttrSynchronizable: false,
    ]
  }

  private var readQuery: CFDictionary {
    var query = baseQuery
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne
    return query as CFDictionary
  }
}
