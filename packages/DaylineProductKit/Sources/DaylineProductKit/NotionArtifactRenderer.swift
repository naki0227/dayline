import AppleIntelligenceKit
import ContextCoreKit

enum NotionArtifactRenderer {
  static func markdown(for artifact: SemanticArtifactDocument) -> String {
    let presentation = ArtifactPresentation(artifact: artifact)
    var blocks = [presentation.summary]
    for section in presentation.sections {
      blocks.append("## \(title(for: section.kind))")
      blocks.append(section.items.map { "- \($0)" }.joined(separator: "\n"))
    }
    blocks.append("---\nDayline evidence: \(presentation.sourceCount)")
    return blocks.joined(separator: "\n\n")
  }

  private static func title(for kind: ArtifactSectionKind) -> String {
    switch kind {
    case .highlights: "Highlights"
    case .topics: "Topics"
    case .decisions: "Decisions"
    case .todos: "TODOs"
    case .ideas: "Ideas"
    case .questions: "Questions"
    }
  }
}
