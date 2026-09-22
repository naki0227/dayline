import ContextCoreKit
import SwiftUI

struct SettingsView: View {
  @Bindable var model: DaylineAppModel
  @State private var capabilities = AppCapabilityModel()

  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            CapabilitiesView(model: capabilities)
          } label: {
            settingsRow(
              title: "権限と利用条件",
              detail: "マイク・音声認識・Apple Intelligence",
              symbol: "checkmark.shield.fill"
            )
          }
          .accessibilityIdentifier("dayline.settings.capabilities")

          NavigationLink {
            ContextSourcesSettingsView(model: model)
          } label: {
            settingsRow(
              title: "Context Sources",
              detail: "Daylineが使用してよい情報",
              symbol: "switch.2"
            )
          }
          .accessibilityIdentifier("dayline.settings.sources")
        } header: {
          Text("Privacy & Data")
        }

        Section("Integrations") {
          NavigationLink {
            IntegrationsView(model: model)
          } label: {
            settingsRow(
              title: "連携を管理",
              detail: integrationDetail,
              symbol: "puzzlepiece.extension.fill"
            )
          }
        }

        Section("About") {
          LabeledContent("Context schema", value: "v\(ContextCoreKit.schemaVersion)")
          LabeledContent("処理方式", value: "端末内優先")
        }
      }
      .scrollContentBackground(.hidden)
      .background(DaylineTheme.canvas.opacity(0.55))
      .navigationTitle("Settings")
      .task { await capabilities.refresh() }
    }
  }

  private func settingsRow(title: String, detail: String, symbol: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: symbol)
        .foregroundStyle(DaylineTheme.sky)
        .frame(width: 30, height: 30)
        .background(DaylineTheme.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var integrationDetail: String {
    model.notionConnection.isConnected ? "Notion接続済み" : "Notion・Calendar・Mac"
  }
}
