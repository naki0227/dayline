import DaylineProductKit
import SwiftUI

struct DailySummaryCard: View {
  @Bindable var summary: DailySummaryModel
  let onOpenNotion: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label("今日のまとめ", systemImage: "sparkles")
          .font(.headline)
          .foregroundStyle(DaylineTheme.navy)
        Spacer()
        if summary.state == .ready {
          Text("AI Summary")
            .font(.caption2.bold())
            .foregroundStyle(DaylineTheme.sky)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(DaylineTheme.sky.opacity(0.12), in: Capsule())
        }
      }
      content
      Button {
        Task { await summary.generate() }
      } label: {
        Label("今日を要約", systemImage: "sparkles")
      }
      .buttonStyle(.borderedProminent)
      .tint(DaylineTheme.sky)
      .disabled(summary.state == .generating)
      .accessibilityIdentifier("dayline.daily.generate")
      if summary.summary != nil {
        Button("Notionへ出力", action: onOpenNotion)
          .accessibilityIdentifier("dayline.notion.open")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .daylineCard()
  }

  @ViewBuilder
  private var content: some View {
    if let presentation = summary.presentation {
      ArtifactSectionsView(
        presentation: presentation,
        accessibilityPrefix: "dayline.daily"
      )
    } else {
      Text(statusText)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("dayline.daily.status")
    }
  }

  private var statusText: String {
    switch summary.state {
    case .idle: "録音を始めると、出来事・決定・TODOを端末上で整理できます。"
    case .generating: "要約を作成中…"
    case .ready: "要約ができました。"
    case .empty: "今日のContextはまだありません。"
    case .sourceDisabled: "要約に使う情報源を1つ以上有効にしてください。"
    case .intelligenceUnavailable: "Apple Intelligenceが利用可能になると要約できます。"
    case .failed: "要約を作成できませんでした。"
    }
  }
}
