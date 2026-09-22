import ContextCaptureKit
import DaylineProductKit
import SwiftUI

struct TodayView: View {
  @Bindable var model: DaylineAppModel
  let onOpenNotion: () -> Void

  private var capture: CaptureCoordinator { model.capture }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          header
          recordingHero
          sourceStatus
          transcript
          DailySummaryCard(summary: model.dailySummary, onOpenNotion: onOpenNotion)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
      }
      .background(DaylineTheme.canvas.opacity(0.55).ignoresSafeArea())
      .toolbar(.hidden, for: .navigationBar)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
      Text(greeting)
        .font(.largeTitle.bold())
        .foregroundStyle(DaylineTheme.navy)
    }
    .padding(.top, 12)
  }

  private var recordingHero: some View {
    VStack(spacing: 16) {
      Text("DAILY RECORDING")
        .font(.caption.weight(.semibold))
        .tracking(0.8)
        .foregroundStyle(.white.opacity(0.55))
      Image(systemName: capture.audioState == .recording ? "waveform" : "mic.fill")
        .font(.system(size: 30, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 88, height: 88)
        .background(heroButtonColor, in: Circle())
        .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 8) }
      VStack(spacing: 4) {
        Text(statusText)
          .font(.title3.bold())
          .foregroundStyle(.white)
          .accessibilityIdentifier("dayline.capture.status")
        Text(detailText)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)
      }
      Button {
        Task { await model.toggleDailyCapture() }
      } label: {
        Label(
          buttonText, systemImage: capture.dailyState == .running ? "stop.fill" : "record.circle"
        )
        .frame(maxWidth: .infinity)
        .frame(height: 48)
      }
      .buttonStyle(.borderedProminent)
      .tint(capture.dailyState == .running ? DaylineTheme.recording : DaylineTheme.sky)
      .disabled(isCaptureButtonDisabled)
      .accessibilityIdentifier("dayline.capture.toggle")
    }
    .padding(24)
    .background(DaylineTheme.heroGradient)
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .shadow(color: DaylineTheme.navy.opacity(0.2), radius: 18, y: 8)
  }

  private var sourceStatus: some View {
    HStack(spacing: 10) {
      sourcePill("Audio", icon: "waveform", enabled: model.sourcePolicy.isEnabled(.audio))
      sourcePill("Calendar", icon: "calendar", enabled: model.sourcePolicy.isEnabled(.calendar))
      sourcePill("Browser", icon: "globe", enabled: model.sourcePolicy.isEnabled(.browser))
    }
  }

  @ViewBuilder
  private var transcript: some View {
    if let text = capture.transcript.volatile?.text ?? capture.transcript.finalized.last?.text {
      VStack(alignment: .leading, spacing: 8) {
        Label("Live Transcript", systemImage: "quote.bubble")
          .font(.headline)
          .foregroundStyle(DaylineTheme.navy)
        Text(text)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("dayline.transcript.latest")
        Text("端末上で処理")
          .font(.caption)
          .foregroundStyle(DaylineTheme.sky)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .daylineCard()
    }
  }

  private func sourcePill(_ title: String, icon: String, enabled: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: icon)
        .foregroundStyle(enabled ? DaylineTheme.sky : .secondary)
      Text(title)
        .font(.caption.weight(.semibold))
      Text(enabled ? "Active" : "Off")
        .font(.caption2)
        .foregroundStyle(enabled ? .green : .secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .opacity(enabled ? 1 : 0.6)
  }

  private var greeting: String {
    let hour = Calendar.current.component(.hour, from: .now)
    if hour < 12 { return "おはようございます。" }
    if hour < 18 { return "こんにちは。" }
    return "こんばんは。"
  }

  private var heroButtonColor: Color {
    capture.audioState == .recording ? DaylineTheme.recording : DaylineTheme.sky
  }

  private var isCaptureButtonDisabled: Bool {
    capture.dailyState == .starting || capture.dailyState == .stopping
      || !model.sourcePolicy.isEnabled(.audio)
  }

  private var buttonText: String {
    capture.dailyState == .running ? "録音を停止" : "録音を開始"
  }

  private var statusText: String {
    switch capture.dailyState {
    case .stopped: "Dailyを開始"
    case .starting: "開始中…"
    case .stopping: "停止中…"
    case .running:
      switch capture.audioState {
      case .waitingForAudio: "音声を待機中"
      case .interrupted: "録音中断"
      case .unavailable: "録音利用不可"
      case .recording: "録音中"
      case .stopped: "Daily実行中"
      }
    }
  }

  private var detailText: String {
    if let failure = capture.lastFailure { return failureText(failure) }
    return switch capture.audioState {
    case .waitingForAudio: "通話が終わると自動的に再開します"
    case .interrupted: "音声入力の回復を待っています"
    case .unavailable: "設定からマイク権限を確認してください"
    case .recording: "5分ごとに安全に端末へ保存します"
    case .stopped: "今日の出来事を端末上で記録・整理します"
    }
  }

  private func failureText(_ failure: CaptureFailure) -> String {
    switch failure {
    case .microphonePermissionDenied: "マイクの許可が必要です"
    case .audioSessionConfigurationFailed: "録音用の音声設定を準備できません"
    case .audioSessionActivationFailed: "音声セッションを有効にできません"
    case .audioTemporarilyUnavailable: "音声が利用可能になるまで待機します"
    case .storageUnavailable: "録音の保存先を準備できません"
    case .recordingFailed: "録音を開始できませんでした"
    }
  }
}
