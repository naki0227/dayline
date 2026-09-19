import ContextCoreKit
import DaylineProductKit
import SwiftUI

struct NotionExportView: View {
  let artifact: SemanticArtifactDocument
  @Bindable var model: NotionExportModel
  @Bindable var connection: NotionConnectionModel
  let configuration: AppNotionConfiguration

  @Environment(\.dismiss) private var dismiss
  @State private var parentPageID = ""
  @State private var showsConfirmation = false

  var body: some View {
    NavigationStack {
      Form {
        connectionSection
        destinationSection
        Section("送信する内容") {
          Text(artifact.content.text)
            .lineLimit(4)
          Text("生の音声・全文transcript・credentialは送信しません。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Section {
          Button("出力内容を確認") { prepare() }
            .disabled(!connection.isConnected || trimmedParent.isEmpty)
            .accessibilityIdentifier("dayline.notion.prepare")
        }
        exportResultSection
      }
      .navigationTitle("Notionへ出力")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("閉じる") { dismiss() }
        }
      }
      .task {
        parentPageID = configuration.parentPageID()
        await connection.load()
      }
      .onChange(of: connection.destinations) { _, destinations in
        guard
          !destinations.isEmpty,
          !destinations.contains(where: { $0.id == parentPageID })
        else { return }
        parentPageID = destinations[0].id
      }
      .alert("Notionへ送信しますか？", isPresented: $showsConfirmation) {
        Button("キャンセル", role: .cancel) { model.cancel() }
        Button("送信") { Task { await model.confirm() } }
      } message: {
        Text("選択した要約を親ページ \(trimmedParent) の下に作成します。")
      }
    }
  }

  @ViewBuilder
  private var destinationSection: some View {
    Section("保存先") {
      if oauthConnected {
        if connection.destinationLoading {
          ProgressView("共有ページを読み込み中…")
        } else if connection.destinations.isEmpty {
          Text("書き込み可能な共有ページが見つかりません。")
            .foregroundStyle(.secondary)
          if connection.destinationLoadFailed {
            Button("ページを再読み込み") {
              Task { await connection.loadDestinations() }
            }
          }
        } else {
          Picker("親ページ", selection: $parentPageID) {
            ForEach(connection.destinations) { destination in
              Text(destination.title).tag(destination.id)
            }
          }
          .accessibilityIdentifier("dayline.notion.destination")
        }
      } else if connection.isConnected {
        TextField("親ページID", text: $parentPageID)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .accessibilityIdentifier("dayline.notion.parent")
        Text("既存の開発用手動接続を使用しています。")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text("Notionと連携すると保存先を選べます。")
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var connectionSection: some View {
    Section("接続") {
      switch connection.state {
      case .loading:
        ProgressView("接続状態を確認中…")
      case .disconnected:
        Button("Notionと連携") { Task { await connection.connect() } }
          .accessibilityIdentifier("dayline.notion.connect")
      case .connecting:
        ProgressView("Notionに接続中…")
      case .connected(let summary):
        Label(summary.workspaceName, systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .accessibilityIdentifier("dayline.notion.connected")
        Button("接続し直す") { Task { await connection.connect() } }
        Button("連携を解除", role: .destructive) {
          Task { await connection.disconnect() }
        }
        .accessibilityIdentifier("dayline.notion.disconnect")
      case .disconnecting(let summary):
        ProgressView("\(summary.workspaceName) の連携を解除中…")
      case .unavailable:
        Text("Notion OAuthがまだ構成されていません。")
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("dayline.notion.unavailable")
        Button("再試行") { Task { await connection.connect() } }
      case .failed:
        Text("接続状態を更新できませんでした。")
          .foregroundStyle(.red)
          .accessibilityIdentifier("dayline.notion.connection-failure")
        Button("再試行") { Task { await connection.load() } }
      }
      if connection.disconnectRevocationFailed {
        Text(
          "端末上のcredentialは削除しました。"
            + "Notion側の解除は完了を確認できませんでした。"
        )
        .font(.caption)
        .foregroundStyle(.orange)
      }
    }
  }

  @ViewBuilder
  private var exportResultSection: some View {
    if model.state == .succeeded {
      Section {
        Label("Notionへ出力しました", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .accessibilityIdentifier("dayline.notion.success")
      }
    } else if model.state == .failed {
      Section {
        Text(
          "Notionへ出力できませんでした。接続と権限を確認してください。"
        )
        .foregroundStyle(.red)
        .accessibilityIdentifier("dayline.notion.failure")
      }
    }
  }

  private var trimmedParent: String {
    parentPageID.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var oauthConnected: Bool {
    if case .connected(let summary) = connection.state {
      return summary.authorization == .oauth
    }
    return false
  }

  private func prepare() {
    configuration.save(parentPageID: trimmedParent)
    model.prepare(
      artifact: artifact,
      parentPageID: trimmedParent,
      title: "\(artifact.dayId.localDate) Dayline Summary"
    )
    showsConfirmation = model.state == .awaitingConfirmation
  }
}
