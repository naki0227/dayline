import ContextCoreKit
import DaylineProductKit
import Foundation

public enum NotionOutputFailure: Error, Equatable, Sendable {
  case invalidProposal
  case notConfigured
  case unauthorized
  case forbidden
  case notFound
  case rateLimited
  case requestRejected
  case invalidResponse
  case transportUnavailable
}

public struct NotionPageWriter: NotionOutputWriting, Sendable {
  public static let apiVersion = "2026-03-11"

  private let credentials: any NotionCredentialProviding
  private let transport: any NotionTransport
  private let endpoint: String

  public init(
    credentials: any NotionCredentialProviding,
    transport: any NotionTransport = URLSessionNotionTransport(),
    endpoint: String = "https://api.notion.com/v1/pages"
  ) {
    self.credentials = credentials
    self.transport = transport
    self.endpoint = endpoint
  }

  public func write(
    _ approvedProposal: ActionProposalDocument
  ) async throws -> ExternalOutputReceipt {
    let arguments = try arguments(from: approvedProposal)
    let token: String
    do {
      token = try await credentials.accessToken()
    } catch {
      throw NotionOutputFailure.notConfigured
    }
    let request = try request(arguments: arguments, token: token)
    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await transport.data(for: request)
    } catch let error as NotionOutputFailure {
      throw error
    } catch {
      throw NotionOutputFailure.transportUnavailable
    }
    try validate(response)
    do {
      let page = try JSONDecoder().decode(CreatedNotionPage.self, from: data)
      return ExternalOutputReceipt(remoteID: page.id, remoteURL: page.url)
    } catch {
      throw NotionOutputFailure.invalidResponse
    }
  }

  private func arguments(from proposal: ActionProposalDocument) throws -> NotionPageArguments {
    guard
      proposal.tool.integration == "notion",
      proposal.tool.name == "notion.page",
      proposal.tool.operation == "create",
      proposal.effect == "create",
      proposal.permission.confirmation == "required",
      case .string(let parent) = proposal.arguments["parent_page_id"],
      case .string(let title) = proposal.arguments["title"],
      case .string(let markdown) = proposal.arguments["markdown"],
      !parent.isEmpty,
      !title.isEmpty,
      !markdown.isEmpty,
      markdown.utf8.count <= 100_000
    else { throw NotionOutputFailure.invalidProposal }
    return NotionPageArguments(
      parentPageID: parent,
      title: String(title.prefix(2_000)),
      markdown: markdown
    )
  }

  private func request(arguments: NotionPageArguments, token: String) throws -> URLRequest {
    guard let endpoint = URL(string: endpoint) else {
      throw NotionOutputFailure.invalidResponse
    }
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue(Self.apiVersion, forHTTPHeaderField: "Notion-Version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(CreateNotionPageRequest(arguments: arguments))
    return request
  }

  private func validate(_ response: HTTPURLResponse) throws {
    switch response.statusCode {
    case 200..<300: return
    case 401: throw NotionOutputFailure.unauthorized
    case 403: throw NotionOutputFailure.forbidden
    case 404: throw NotionOutputFailure.notFound
    case 429: throw NotionOutputFailure.rateLimited
    default: throw NotionOutputFailure.requestRejected
    }
  }
}

private struct NotionPageArguments {
  let parentPageID: String
  let title: String
  let markdown: String
}

private struct CreateNotionPageRequest: Encodable {
  let parent: Parent
  let properties: Properties
  let markdown: String

  init(arguments: NotionPageArguments) {
    parent = Parent(type: "page_id", pageId: arguments.parentPageID)
    properties = Properties(
      title: TitleProperty(
        type: "title",
        title: [RichText(type: "text", text: TextContent(content: arguments.title))]
      )
    )
    markdown = arguments.markdown
  }

  struct Parent: Encodable {
    let type: String
    let pageId: String
  }
  struct Properties: Encodable { let title: TitleProperty }
  struct TitleProperty: Encodable {
    let type: String
    let title: [RichText]
  }
  struct RichText: Encodable {
    let type: String
    let text: TextContent
  }
  struct TextContent: Encodable { let content: String }
}

private struct CreatedNotionPage: Decodable {
  let id: String
  let url: URL?
}
