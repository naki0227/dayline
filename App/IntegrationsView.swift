import SwiftUI

struct IntegrationsView: View {
  @Bindable var model: DaylineAppModel

  var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        integrationCard(
          title: "Notion",
          detail: notionDetail,
          symbol: "doc.text.fill",
          connected: model.notionConnection.isConnected
        ) {
          NotionConnectionView(model: model.notionConnection)
        }

        unavailableCard(
          title: "Google Calendar",
          detail: "OAuth連携はIssue #20で準備中",
          symbol: "calendar"
        )
        unavailableCard(
          title: "Mac Companion",
          detail: "BrowserとTerminalのContext収集はIssue #21で準備中",
          symbol: "laptopcomputer"
        )
      }
      .padding(20)
    }
    .background(DaylineTheme.canvas.opacity(0.55).ignoresSafeArea())
    .navigationTitle("Integrations")
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.notionConnection.load() }
  }

  private func integrationCard<Destination: View>(
    title: String,
    detail: String,
    symbol: String,
    connected: Bool,
    @ViewBuilder destination: () -> Destination
  ) -> some View {
    NavigationLink(destination: destination) {
      HStack(spacing: 14) {
        integrationIcon(symbol)
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.headline).foregroundStyle(.primary)
          Text(detail).font(.caption).foregroundStyle(.secondary)
          Label(
            connected ? "接続済み" : "未接続", systemImage: connected ? "checkmark.circle.fill" : "circle"
          )
          .font(.caption.weight(.semibold))
          .foregroundStyle(connected ? .green : .secondary)
        }
        Spacer()
        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
      }
      .daylineCard()
    }
    .buttonStyle(.plain)
  }

  private func unavailableCard(title: String, detail: String, symbol: String) -> some View {
    HStack(spacing: 14) {
      integrationIcon(symbol)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.headline)
        Text(detail).font(.caption).foregroundStyle(.secondary)
        Text("準備中").font(.caption.weight(.semibold)).foregroundStyle(.orange)
      }
      Spacer()
    }
    .daylineCard()
  }

  private func integrationIcon(_ symbol: String) -> some View {
    Image(systemName: symbol)
      .font(.title3)
      .foregroundStyle(DaylineTheme.sky)
      .frame(width: 44, height: 44)
      .background(DaylineTheme.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
  }

  private var notionDetail: String {
    switch model.notionConnection.state {
    case .connected(let summary), .disconnecting(let summary): summary.workspaceName
    case .loading: "接続状態を確認中"
    case .connecting: "接続中"
    case .disconnected: "要約を確認付きで出力"
    case .unavailable: "OAuth設定が利用できません"
    case .failed: "接続状態を取得できません"
    }
  }
}

private struct NotionConnectionView: View {
  @Bindable var model: NotionConnectionModel

  var body: some View {
    Form {
      Section("Connection") {
        switch model.state {
        case .loading:
          ProgressView("確認中…")
        case .disconnected:
          Button("Notionと連携") { Task { await model.connect() } }
            .accessibilityIdentifier("dayline.notion.connect")
        case .connecting:
          ProgressView("Notionに接続中…")
        case .connected(let summary):
          Label(summary.workspaceName, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .accessibilityIdentifier("dayline.notion.connected")
          Button("連携を解除", role: .destructive) { Task { await model.disconnect() } }
            .accessibilityIdentifier("dayline.notion.disconnect")
        case .disconnecting(let summary):
          ProgressView("\(summary.workspaceName) の連携を解除中…")
        case .unavailable:
          Text("Notion OAuthが構成されていません。")
          Button("再試行") { Task { await model.connect() } }
        case .failed:
          Text("接続状態を更新できませんでした。")
          Button("再試行") { Task { await model.load() } }
        }
      }
      Section("Privacy") {
        Text("CredentialはKeychainに保存し、Apple Intelligenceへ渡しません。書き込み前には必ず確認します。")
      }
    }
    .navigationTitle("Notion")
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.load() }
  }
}
