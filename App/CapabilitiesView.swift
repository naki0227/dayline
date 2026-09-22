import SwiftUI
import UIKit

struct CapabilitiesView: View {
  @Bindable var model: AppCapabilityModel
  @Environment(\.openURL) private var openURL

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(AppCapability.allCases) { capability in
          CapabilityCard(
            capability: capability,
            state: model.state(for: capability),
            action: { handle(capability) }
          )
        }
      }
      .padding(20)
    }
    .background(DaylineTheme.canvas.opacity(0.55).ignoresSafeArea())
    .navigationTitle("権限と利用条件")
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.refresh() }
    .refreshable { await model.refresh() }
  }

  private func handle(_ capability: AppCapability) {
    let state = model.state(for: capability)
    if state == .permissionNeeded {
      Task { await model.request(capability) }
      return
    }
    guard state != .available, let url = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    openURL(url)
  }
}

private struct CapabilityCard: View {
  let capability: AppCapability
  let state: AppCapabilityState
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: symbol)
          .font(.title3)
          .foregroundStyle(DaylineTheme.sky)
          .frame(width: 38, height: 38)
          .background(DaylineTheme.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
        VStack(alignment: .leading, spacing: 5) {
          Text(title).font(.headline)
          Label(stateTitle, systemImage: stateSymbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(stateColor)
            .accessibilityIdentifier("dayline.capability.\(capability.rawValue).status")
        }
        Spacer()
      }
      Text(reason)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text("利用可能になる機能: \(enables)")
        .font(.caption)
        .foregroundStyle(.secondary)
      if shouldShowAction {
        Button(actionTitle, action: action)
          .buttonStyle(.borderedProminent)
          .tint(DaylineTheme.sky)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .daylineCard()
  }

  private var title: String {
    switch capability {
    case .microphone: "マイク"
    case .speechRecognition: "音声認識"
    case .appleIntelligence: "Apple Intelligence"
    case .notifications: "通知"
    case .calendar: "カレンダー"
    case .backgroundAudio: "バックグラウンド録音"
    }
  }

  private var symbol: String {
    switch capability {
    case .microphone: "mic.fill"
    case .speechRecognition: "waveform"
    case .appleIntelligence: "apple.intelligence"
    case .notifications: "bell.fill"
    case .calendar: "calendar"
    case .backgroundAudio: "lock.open.fill"
    }
  }

  private var reason: String {
    switch capability {
    case .microphone: "DailyとLive Meetingで音声を記録するために使用します。"
    case .speechRecognition: "録音を端末上でリアルタイムに文字起こしします。"
    case .appleIntelligence: "要約、決定事項、TODO、質問を端末上で整理します。"
    case .notifications: "要約や会議処理の完了を知らせます。"
    case .calendar: "許可した予定をContextとして利用します。"
    case .backgroundAudio: "画面を閉じてもDaily録音を継続します。"
    }
  }

  private var enables: String {
    switch capability {
    case .microphone: "Daily録音、Live Meeting"
    case .speechRecognition: "ライブ文字起こし"
    case .appleIntelligence: "Daily要約、会議整理"
    case .notifications: "完了通知"
    case .calendar: "予定Context"
    case .backgroundAudio: "長時間録音"
    }
  }

  private var stateTitle: String {
    switch state {
    case .available: "利用可能"
    case .permissionNeeded: "許可が必要"
    case .denied: "拒否されています"
    case .preparing: "設定またはモデルの準備が必要"
    case .deviceNotEligible: "この端末は対象外"
    case .unsupportedOperatingSystem: "OSが対応していません"
    }
  }

  private var stateSymbol: String {
    state == .available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
  }

  private var stateColor: Color {
    switch state {
    case .available: .green
    case .permissionNeeded, .preparing: .orange
    case .denied: .red
    case .deviceNotEligible, .unsupportedOperatingSystem: .secondary
    }
  }

  private var actionTitle: String {
    state == .permissionNeeded ? "許可する" : "iOS設定を開く"
  }

  private var shouldShowAction: Bool {
    state != .available && state != .deviceNotEligible
      && state != .unsupportedOperatingSystem && capability != .backgroundAudio
  }
}
