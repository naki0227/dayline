import DaylineProductKit
import SwiftUI

struct DailySummaryCard: View {
  @Bindable var summary: DailySummaryModel
  let onOpenNotion: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("今日のまとめ")
        .font(.headline)
      content
      Button {
        Task { await summary.generate() }
      } label: {
        Label("今日を要約", systemImage: "sparkles")
      }
      .disabled(summary.state == .generating)
      .accessibilityIdentifier("dayline.daily.generate")
      if summary.summary != nil {
        Button("Notionへ出力", action: onOpenNotion)
          .accessibilityIdentifier("dayline.notion.open")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
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
    case .idle: "録音したContextから端末上で要約します。"
    case .generating: "要約を作成中…"
    case .ready: "要約ができました。"
    case .empty: "今日のContextはまだありません。"
    case .sourceDisabled: "要約に使う情報源を1つ以上有効にしてください。"
    case .intelligenceUnavailable: "Apple Intelligenceが利用可能になると要約できます。"
    case .failed: "要約を作成できませんでした。"
    }
  }
}
