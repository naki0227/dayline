import ContextCaptureKit
import ContextCoreKit
import DaylineProductKit
import SwiftUI

struct RootView: View {
  @Bindable var model: DaylineAppModel
  @State private var showsNotionExport = false

  private var capture: CaptureCoordinator { model.capture }
  private var dailySummary: DailySummaryModel { model.dailySummary }
  private var liveCapture: LiveMeetingCoordinator { model.liveCapture }
  private var liveMeeting: LiveMeetingModel { model.liveMeeting }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          statusCard
          transcriptCard
          DailySummaryCard(summary: dailySummary) {
            showsNotionExport = true
          }
          liveMeetingCard
          PrivacySourcesView(policy: model.sourcePolicy) { source, isEnabled in
            Task { await model.setSource(source, enabled: isEnabled) }
          }
          captureButton
          Text("Context schema v\(ContextCoreKit.schemaVersion)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(24)
      }
      .navigationTitle("Dayline")
      .sheet(isPresented: $showsNotionExport) {
        if let artifact = dailySummary.summary {
          NotionExportView(
            artifact: artifact,
            model: model.notionExport,
            connection: model.notionConnection,
            configuration: model.notionConfiguration
          )
        }
      }
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
    .disabled(
      capture.dailyState == .starting || capture.dailyState == .stopping
        || !model.sourcePolicy.isEnabled(.audio)
    )
    .accessibilityIdentifier("dayline.capture.toggle")
  }

  private var statusText: String {
    switch capture.dailyState {
    case .stopped: "停止中"
    case .starting: "開始中"
    case .running:
      switch capture.audioState {
      case .waitingForAudio: "音声を待機中"
      case .interrupted: "録音中断"
      case .unavailable: "録音利用不可"
      case .recording: "録音中"
      case .stopped: "Daily実行中"
      }
    case .stopping: "停止中"
    }
  }

  private var detailText: String {
    if let failure = capture.lastFailure {
      return failureText(failure)
    }
    return switch capture.audioState {
    case .waitingForAudio: "通話が終わると自動的に録音を開始します。"
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
    case .audioSessionConfigurationFailed: "録音用の音声設定を準備できません。"
    case .audioSessionActivationFailed: "音声セッションを有効にできません。"
    case .audioTemporarilyUnavailable: "音声が利用可能になるまで待機します。"
    case .storageUnavailable: "録音の保存先を準備できません。"
    case .recordingFailed: "録音を開始できませんでした。"
    }
  }
}
