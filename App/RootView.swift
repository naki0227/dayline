import ContextCaptureKit
import ContextCoreKit
import DaylineProductKit
import SwiftUI

struct RootView: View {
  @Bindable var model: DaylineAppModel

  private var capture: CaptureCoordinator { model.capture }
  private var dailySummary: DailySummaryModel { model.dailySummary }
  private var liveCapture: LiveMeetingCoordinator { model.liveCapture }
  private var liveMeeting: LiveMeetingModel { model.liveMeeting }

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        statusCard
        transcriptCard
        dailySummaryCard
        liveMeetingCard
        Spacer()
        captureButton
        Text("Context schema v\(ContextCoreKit.schemaVersion)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(24)
      .navigationTitle("Dayline")
    }
  }

  private var liveMeetingCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Live Meeting")
          .font(.headline)
        Spacer()
        if liveCapture.state == .running {
          Label("Live", systemImage: "waveform.circle.fill")
            .foregroundStyle(.red)
            .accessibilityIdentifier("dayline.live.status")
        }
      }
      if let presentation = liveMeeting.presentation {
        ArtifactSectionsView(
          presentation: presentation,
          accessibilityPrefix: "dayline.live"
        )
      } else {
        Text(liveMeetingText)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("dayline.live.content")
      }
      Button {
        Task { await model.toggleLiveMeeting() }
      } label: {
        Label(
          liveCapture.state == .running ? "会議を終了" : "会議を開始",
          systemImage: liveCapture.state == .running ? "stop.circle.fill" : "mic.circle.fill"
        )
      }
      .accessibilityIdentifier("dayline.live.toggle")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
  }

  private var liveMeetingText: String {
    if let latest = liveMeeting.latest { return latest.content.text }
    if let volatile = liveCapture.transcript.volatile?.text { return volatile }
    if let finalized = liveCapture.transcript.finalized.last?.text { return finalized }
    return switch liveCapture.state {
    case .stopped: "会議中の発話を端末上で逐次整理します。"
    case .starting: "Live Meetingを開始中…"
    case .running: "聞き取り中…"
    case .stopping: "最後の発話を確定中…"
    case .unavailable: "この端末ではLive Meetingを開始できません。"
    }
  }

  private var dailySummaryCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("今日のまとめ")
        .font(.headline)
      if let presentation = dailySummary.presentation {
        ArtifactSectionsView(
          presentation: presentation,
          accessibilityPrefix: "dayline.daily"
        )
      } else {
        Text(dailySummaryStatusText)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("dayline.daily.status")
      }
      Button {
        Task { await dailySummary.generate() }
      } label: {
        Label("今日を要約", systemImage: "sparkles")
      }
      .disabled(dailySummary.state == .generating)
      .accessibilityIdentifier("dayline.daily.generate")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
  }

  private var dailySummaryStatusText: String {
    switch dailySummary.state {
    case .idle: "録音したContextから端末上で要約します。"
    case .generating: "要約を作成中…"
    case .ready: "要約ができました。"
    case .empty: "今日のContextはまだありません。"
    case .intelligenceUnavailable: "Apple Intelligenceが利用可能になると要約できます。"
    case .failed: "要約を作成できませんでした。"
    }
  }

  @ViewBuilder
  private var transcriptCard: some View {
    if let text = capture.transcript.volatile?.text ?? capture.transcript.finalized.last?.text {
      VStack(alignment: .leading, spacing: 6) {
        Text("文字起こし")
          .font(.headline)
        Text(text)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("dayline.transcript.latest")
      }
      .padding()
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
  }

  private var statusCard: some View {
    VStack(spacing: 8) {
      Image(systemName: capture.audioState == .recording ? "waveform.circle.fill" : "circle")
        .font(.system(size: 52))
        .foregroundStyle(capture.audioState == .recording ? .red : .secondary)
      Text(statusText)
        .font(.title2.weight(.semibold))
        .accessibilityIdentifier("dayline.capture.status")
      Text(detailText)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
  }

  private var captureButton: some View {
    Button {
      Task { await model.toggleDailyCapture() }
    } label: {
      Label(buttonText, systemImage: capture.dailyState == .running ? "stop.fill" : "record.circle")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    .buttonStyle(.borderedProminent)
    .tint(capture.dailyState == .running ? .red : .accentColor)
    .disabled(capture.dailyState == .starting || capture.dailyState == .stopping)
    .accessibilityIdentifier("dayline.capture.toggle")
  }

  private var statusText: String {
    switch capture.dailyState {
    case .stopped: "停止中"
    case .starting: "開始中"
    case .running: capture.audioState == .interrupted ? "録音中断" : "録音中"
    case .stopping: "停止中"
    }
  }

  private var detailText: String {
    if let failure = capture.lastFailure {
      return failureText(failure)
    }
    return switch capture.audioState {
    case .interrupted: "通話や他の音声が終了すると録音を再開できます。"
    case .unavailable: "マイクを利用できません。設定を確認してください。"
    case .recording: "5分ごとにローカルchunkへ保存します。"
    case .stopped: "AIが使えない場合も録音と保存は継続できます。"
    }
  }

  private var buttonText: String {
    capture.dailyState == .running ? "録音を停止" : "録音を開始"
  }

  private func failureText(_ failure: CaptureFailure) -> String {
    switch failure {
    case .microphonePermissionDenied: "マイクの許可が必要です。"
    case .audioSessionUnavailable: "音声セッションを開始できません。"
    case .storageUnavailable: "録音の保存先を準備できません。"
    case .recordingFailed: "録音を開始できませんでした。"
    }
  }
}
