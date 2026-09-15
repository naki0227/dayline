import DaylineProductKit
import SwiftUI

struct PrivacySourcesView: View {
  let policy: DaylineSourcePolicy
  let onChange: (DaylineContextSource, Bool) -> Void

  private let visibleSources: [DaylineContextSource] = [.audio, .browser, .shell, .calendar]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("プライバシーと情報源", systemImage: "hand.raised.fill")
          .font(.headline)
        Spacer()
        Text("端末内のみ")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
          .accessibilityIdentifier("dayline.privacy.processing")
      }
      Text("明示した出力操作を除き、詳細Contextを端末外へ送信しません。")
        .font(.caption)
        .foregroundStyle(.secondary)
      ForEach(visibleSources, id: \.self) { source in
        Toggle(isOn: binding(for: source)) {
          VStack(alignment: .leading, spacing: 2) {
            Text(title(for: source))
            Text(detail(for: source))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .accessibilityIdentifier("dayline.source.\(source.rawValue)")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
  }

  private func binding(for source: DaylineContextSource) -> Binding<Bool> {
    Binding(
      get: { policy.isEnabled(source) },
      set: { onChange(source, $0) }
    )
  }

  private func title(for source: DaylineContextSource) -> String {
    switch source {
    case .audio: "音声と文字起こし"
    case .browser: "Chrome履歴"
    case .shell: "Terminal操作"
    case .calendar: "カレンダー"
    case .github: "GitHub"
    case .notion: "Notion"
    }
  }

  private func detail(for source: DaylineContextSource) -> String {
    switch source {
    case .audio: "Daily録音とLive Meeting"
    case .browser, .shell: "Mac collector接続時に収集"
    case .calendar: "連携後、許可した予定だけを参照"
    case .github, .notion: "連携後に利用"
    }
  }
}
