import DaylineProductKit
import SwiftUI

struct ArtifactSectionsView: View {
  let presentation: ArtifactPresentation
  let accessibilityPrefix: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(presentation.summary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("\(accessibilityPrefix).summary")
      ForEach(presentation.sections) { section in
        VStack(alignment: .leading, spacing: 4) {
          Label(title(for: section.kind), systemImage: symbol(for: section.kind))
            .font(.subheadline.weight(.semibold))
          ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
            Text("• \(item)")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .accessibilityIdentifier("\(accessibilityPrefix).\(section.kind.rawValue)")
      }
      Text("根拠 \(presentation.sourceCount)件")
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("\(accessibilityPrefix).provenance")
    }
  }

  private func title(for kind: ArtifactSectionKind) -> String {
    switch kind {
    case .highlights: "ハイライト"
    case .topics: "トピック"
    case .decisions: "決定"
    case .todos: "TODO"
    case .ideas: "アイデア"
    case .questions: "質問"
    }
  }

  private func symbol(for kind: ArtifactSectionKind) -> String {
    switch kind {
    case .highlights: "star"
    case .topics: "tag"
    case .decisions: "checkmark.seal"
    case .todos: "checklist"
    case .ideas: "lightbulb"
    case .questions: "questionmark.circle"
    }
  }
}
