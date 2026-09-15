import Foundation

public struct SemanticSections: Codable, Equatable, Sendable {
  public static let attributeKey = "sections_v1"

  public let summary: String
  public let highlights: [String]
  public let topics: [String]
  public let decisions: [String]
  public let todos: [String]
  public let ideas: [String]
  public let questions: [String]

  public init(
    summary: String,
    highlights: [String],
    topics: [String],
    decisions: [String],
    todos: [String],
    ideas: [String],
    questions: [String]
  ) {
    self.summary = summary
    self.highlights = highlights
    self.topics = topics
    self.decisions = decisions
    self.todos = todos
    self.ideas = ideas
    self.questions = questions
  }
}

public enum SemanticSectionsCodec {
  public static func attributes(
    for sections: SemanticSections,
    language: String
  ) throws -> [String: String] {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(sections)
    guard let document = String(data: data, encoding: .utf8) else {
      throw SemanticSectionsCodecError.invalidEncoding
    }
    return [
      "language": language,
      SemanticSections.attributeKey: document,
    ]
  }

  public static func decode(
    from attributes: [String: String]
  ) throws -> SemanticSections {
    guard
      let document = attributes[SemanticSections.attributeKey],
      let data = document.data(using: .utf8)
    else {
      throw SemanticSectionsCodecError.missingDocument
    }
    do {
      return try JSONDecoder().decode(SemanticSections.self, from: data)
    } catch {
      throw SemanticSectionsCodecError.invalidDocument
    }
  }
}

public enum SemanticSectionsCodecError: Error, Equatable, Sendable {
  case missingDocument
  case invalidEncoding
  case invalidDocument
}
