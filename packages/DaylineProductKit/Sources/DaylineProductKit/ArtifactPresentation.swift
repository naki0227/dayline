import AppleIntelligenceKit
import ContextCoreKit

public enum ArtifactSectionKind: String, CaseIterable, Sendable {
  case highlights
  case topics
  case decisions
  case todos
  case ideas
  case questions
}

public struct ArtifactSectionPresentation: Equatable, Identifiable, Sendable {
  public var id: ArtifactSectionKind { kind }
  public let kind: ArtifactSectionKind
  public let items: [String]

  public init(kind: ArtifactSectionKind, items: [String]) {
    self.kind = kind
    self.items = items
  }
}

public struct ArtifactPresentation: Equatable, Sendable {
  public let summary: String
  public let sections: [ArtifactSectionPresentation]
  public let sourceCount: Int
  public let isStructured: Bool

  public init(artifact: SemanticArtifactDocument) {
    summary = artifact.content.text
    sourceCount = artifact.sourceEventIds.count + artifact.sourceArtifactIds.count
    do {
      let structured = try SemanticSectionsCodec.decode(from: artifact.content.attributes)
      sections = Self.nonEmptySections(structured)
      isStructured = true
    } catch {
      sections = []
      isStructured = false
    }
  }

  private static func nonEmptySections(
    _ sections: SemanticSections
  ) -> [ArtifactSectionPresentation] {
    [
      ArtifactSectionPresentation(kind: .highlights, items: sections.highlights),
      ArtifactSectionPresentation(kind: .topics, items: sections.topics),
      ArtifactSectionPresentation(kind: .decisions, items: sections.decisions),
      ArtifactSectionPresentation(kind: .todos, items: sections.todos),
      ArtifactSectionPresentation(kind: .ideas, items: sections.ideas),
      ArtifactSectionPresentation(kind: .questions, items: sections.questions),
    ].filter { !$0.items.isEmpty }
  }
}
