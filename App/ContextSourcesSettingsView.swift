import DaylineProductKit
import SwiftUI

struct ContextSourcesSettingsView: View {
  @Bindable var model: DaylineAppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("DaylineがContextとして使用してよい情報を、情報源ごとに選択できます。OS権限やサービス接続とは別に管理されます。")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        ForEach(DaylineContextSource.allCases, id: \.self) { source in
          sourceCard(source)
        }

        Label("詳細Contextは、明示した出力操作を除き端末外へ送りません。", systemImage: "lock.shield.fill")
          .font(.caption)
          .foregroundStyle(.green)
          .padding(.top, 6)
          .accessibilityIdentifier("dayline.privacy.processing")
      }
      .padding(20)
    }
    .background(DaylineTheme.canvas.opacity(0.55).ignoresSafeArea())
    .navigationTitle("Context Sources")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func sourceCard(_ source: DaylineContextSource) -> some View {
    HStack(spacing: 14) {
      Image(systemName: symbol(for: source))
        .foregroundStyle(DaylineTheme.sky)
        .frame(width: 38, height: 38)
        .background(DaylineTheme.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
      VStack(alignment: .leading, spacing: 3) {
        Text(title(for: source)).font(.headline)
        Text(detail(for: source)).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Toggle("", isOn: binding(for: source))
        .labelsHidden()
        .tint(DaylineTheme.sky)
        .accessibilityIdentifier("dayline.source.\(source.rawValue)")
    }
    .daylineCard()
  }

  private func binding(for source: DaylineContextSource) -> Binding<Bool> {
    Binding(
      get: { model.sourcePolicy.isEnabled(source) },
      set: { enabled in Task { await model.setSource(source, enabled: enabled) } }
    )
  }

  private func title(for source: DaylineContextSource) -> String {
    switch source {
    case .audio: "Audio"
    case .browser: "Browser"
    case .shell: "Terminal"
    case .calendar: "Calendar"
    case .github: "GitHub"
    case .notion: "Notion"
    }
  }

  private func detail(for source: DaylineContextSource) -> String {
    switch source {
    case .audio: "Daily録音とLive Meeting"
    case .browser, .shell: "Mac Companionの接続が必要"
    case .calendar: "Calendar連携後に予定を参照"
    case .github: "GitHub連携は準備中"
    case .notion: "接続したWorkspaceの許可済み情報"
    }
  }

  private func symbol(for source: DaylineContextSource) -> String {
    switch source {
    case .audio: "waveform"
    case .browser: "globe"
    case .shell: "terminal.fill"
    case .calendar: "calendar"
    case .github: "chevron.left.forwardslash.chevron.right"
    case .notion: "doc.text.fill"
    }
  }
}
