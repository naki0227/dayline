import Foundation

public enum NotionDestinationFailure: Error, Equatable, Sendable {
  case notConfigured
  case unauthorized
  case rejected
  case transportUnavailable
  case invalidResponse
}

public struct NotionDestination: Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let url: URL?

  public init(id: String, title: String, url: URL?) {
    self.id = id
    self.title = title
    self.url = url
  }
}

public protocol NotionDestinationListing: Sendable {
  func listDestinations() async throws -> [NotionDestination]
}

public struct NotionPageDirectory: NotionDestinationListing, Sendable {
  private static let apiVersion = "2026-03-11"
  private let credentials: any NotionCredentialProviding
  private let transport: any NotionTransport
  private let endpoint: String

  public init(
    credentials: any NotionCredentialProviding,
    transport: any NotionTransport = URLSessionNotionTransport(),
    endpoint: String = "https://api.notion.com/v1/search"
  ) {
    self.credentials = credentials
    self.transport = transport
    self.endpoint = endpoint
  }

  public func listDestinations() async throws -> [NotionDestination] {
    guard let endpoint = URL(string: self.endpoint) else {
      throw NotionDestinationFailure.notConfigured
    }
    let token: String
    do {
      token = try await credentials.accessToken()
    } catch {
      throw NotionDestinationFailure.notConfigured
    }
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue(Self.apiVersion, forHTTPHeaderField: "Notion-Version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(Self.searchBody.utf8)

    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await transport.data(for: request)
    } catch {
      throw NotionDestinationFailure.transportUnavailable
    }
    switch response.statusCode {
    case 200: break
    case 401, 403: throw NotionDestinationFailure.unauthorized
    default: throw NotionDestinationFailure.rejected
    }
    do {
      let result = try JSONDecoder().decode(SearchResponse.self, from: data)
      return result.results.map(\.destination).sorted {
        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
      }
    } catch {
      throw NotionDestinationFailure.invalidResponse
    }
  }

  private static let searchBody = #"{"filter":{"property":"object","value":"page"},"page_size":50}"#
}

private struct SearchResponse: Decodable {
  let results: [SearchPage]
}

private struct SearchPage: Decodable {
  let id: String
  let url: URL?
  let properties: [String: SearchProperty]

  var destination: NotionDestination {
    let title = properties.values
      .first(where: { $0.type == "title" })?
      .title?
      .map(\.plainText)
      .joined()
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return NotionDestination(
      id: id,
      title: title.flatMap { $0.isEmpty ? nil : $0 } ?? "名称未設定のページ",
      url: url
    )
  }
}

private struct SearchProperty: Decodable {
  let type: String
  let title: [SearchRichText]?
}

private struct SearchRichText: Decodable {
  let plainText: String

  enum CodingKeys: String, CodingKey {
    case plainText = "plain_text"
  }
}
