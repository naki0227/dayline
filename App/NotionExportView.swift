import ContextCoreKit
import DaylineProductKit
import NotionKit
import SwiftUI

struct NotionExportView: View {
  let artifact: SemanticArtifactDocument
  @Bindable var model: NotionExportModel
  let credentials: any NotionCredentialStoring
  let configuration: AppNotionConfiguration

  @Environment(\.dismiss) private var dismiss
  @State private var accessToken = ""
  @State private var parentPageID = ""
  @State private var connectionFailed = false
  @State private var showsConfirmation = false

  var body: some View {
    NavigationStack {
      Form {
        Section("接続") {
          SecureField("Notion access token", text: $accessToken)
            .textContentType(.password)
            .accessibilityIdentifier("dayline.notion.token")
          TextField("親ページID", text: $parentPageID)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("dayline.notion.parent")
        }
        Section("送信する内容") {
          Text(artifact.content.text)
            .lineLimit(4)
          Text("生の音声・全文transcript・credentialは送信しません。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Section {
          Button("出力内容を確認") {
            Task { await prepare() }
          }
          .disabled(trimmedToken.isEmpty || trimmedParent.isEmpty)
          .accessibilityIdentifier("dayline.notion.prepare")
        }
        if model.state == .succeeded {
          Section {
            Label("Notionへ出力しました", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .accessibilityIdentifier("dayline.notion.success")
          }
        } else if model.state == .failed {
          Section {
            Text("Notionへ出力できませんでした。接続と権限を確認してください。")
              .foregroundStyle(.red)
              .accessibilityIdentifier("dayline.notion.failure")
          }
        }
        if connectionFailed {
          Section {
            Text("credentialをKeychainへ保存できませんでした。")
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle("Notionへ出力")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("閉じる") { dismiss() }
        }
      }
      .onAppear { parentPageID = configuration.parentPageID() }
      .alert(
        "Notionへ送信しますか？",
        isPresented: $showsConfirmation
      ) {
        Button("キャンセル", role: .cancel) { model.cancel() }
        Button("送信") { Task { await model.confirm() } }
      } message: {
        Text("選択した要約を親ページ \(trimmedParent) の下に作成します。")
      }
    }
  }

  private var trimmedToken: String {
    accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedParent: String {
    parentPageID.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func prepare() async {
    do {
      connectionFailed = false
      try await credentials.save(accessToken: trimmedToken)
      configuration.save(parentPageID: trimmedParent)
      accessToken = ""
      model.prepare(
        artifact: artifact,
        parentPageID: trimmedParent,
        title: "\(artifact.dayId.localDate) Dayline Summary"
      )
      showsConfirmation = model.state == .awaitingConfirmation
    } catch {
      connectionFailed = true
    }
  }
}
