import ContextCaptureKit
import DaylineProductKit
import SwiftUI

struct LiveMeetingView: View {
  @Bindable var model: DaylineAppModel

  private var capture: LiveMeetingCoordinator { model.liveCapture }
  private var meeting: LiveMeetingModel { model.liveMeeting }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          statusHeader
          capabilityCard
          transcriptCard
          resultCard
          meetingButton
        }
        .padding(20)
      }
      .background(DaylineTheme.canvas.opacity(0.55).ignoresSafeArea())
      .navigationTitle("Live Meeting")
    }
  }

  private var statusHeader: some View {
    VStack(spacing: 12) {
      Image(systemName: capture.state == .running ? "waveform.circle.fill" : "mic.circle.fill")
        .font(.system(size: 64))
        .foregroundStyle(capture.state == .running ? DaylineTheme.recording : DaylineTheme.sky)
      Text(captureTitle)
        .font(.title2.bold())
      Text(captureDetail)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .accessibilityIdentifier("dayline.live.content")
      if capture.state == .running {
        Label("LIVE", systemImage: "circle.fill")
          .font(.caption.bold())
          .foregroundStyle(DaylineTheme.recording)
          .accessibilityIdentifier("dayline.live.status")
      }
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private var capabilityCard: some View {
    VStack(spacing: 12) {
      capabilityRow(
        title: "ライブ文字起こし",
        detail: transcriptionCapabilityDetail,
        available: capture.state != .unavailable
      )
      Divider()
      capabilityRow(
        title: "Apple Intelligenceによる整理",
        detail: intelligenceDetail,
        available: meeting.state != .intelligenceUnavailable && meeting.state != .failed
      )
      if capture.state == .unavailable {
        NavigationLink {
          CapabilitiesView(model: AppCapabilityModel())
        } label: {
          Label("権限と利用条件を確認", systemImage: "gearshape")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(DaylineTheme.sky)
      }
    }
    .daylineCard()
  }

  @ViewBuilder
  private var transcriptCard: some View {
    if let text = capture.transcript.volatile?.text ?? capture.transcript.finalized.last?.text {
      VStack(alignment: .leading, spacing: 10) {
        Text("LIVE TRANSCRIPT")
          .font(.caption.bold())
          .tracking(0.6)
          .foregroundStyle(.secondary)
        Text(text)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("確定済み (capture.transcript.finalized.count)件 · 端末上で処理")
          .font(.caption)
          .foregroundStyle(DaylineTheme.sky)
      }
      .daylineCard()
    }
  }

  @ViewBuilder
  private var resultCard: some View {
    if let presentation = meeting.presentation {
      VStack(alignment: .leading, spacing: 12) {
        Label("会議の現在状態", systemImage: "sparkles")
          .font(.headline)
          .foregroundStyle(DaylineTheme.sky)
        ArtifactSectionsView(presentation: presentation, accessibilityPrefix: "dayline.live")
      }
      .daylineCard()
    } else if capture.state == .running {
      HStack(spacing: 12) {
        ProgressView()
        VStack(alignment: .leading, spacing: 2) {
          Text("会議を整理しています")
            .font(.subheadline.weight(.semibold))
          Text("最初のAI更新は約30秒後です")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .daylineCard()
    }
  }

  private var meetingButton: some View {
    Button {
      Task { await model.toggleLiveMeeting() }
    } label: {
      Label(
        capture.state == .running ? "会議を終了" : "会議を開始",
        systemImage: capture.state == .running ? "stop.fill" : "mic.fill"
      )
      .frame(maxWidth: .infinity)
      .frame(height: 50)
    }
    .buttonStyle(.borderedProminent)
    .tint(capture.state == .running ? DaylineTheme.recording : DaylineTheme.sky)
    .disabled(capture.state == .starting || capture.state == .stopping)
    .accessibilityIdentifier("dayline.live.toggle")
  }

  private func capabilityRow(title: String, detail: String, available: Bool) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        .foregroundStyle(available ? .green : .orange)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.subheadline.weight(.semibold))
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
    }
  }

  private var captureTitle: String {
    switch capture.state {
    case .stopped: "新しい会議"
    case .starting: "準備中…"
    case .running: "聞き取り中"
    case .stopping: "会議を保存中…"
    case .unavailable: "開始できませんでした"
    }
  }

  private var captureDetail: String {
    if let failure = capture.lastTranscriptionFailure { return failureDescription(failure) }
    return switch capture.state {
    case .stopped: "発話をリアルタイムで文字起こしし、決定とTODOを整理します。"
    case .starting: "音声認識モデルとマイクを準備しています。"
    case .running: "文字起こしは端末の外へ送信されません。"
    case .stopping: "最後の発話を確定しています。"
    case .unavailable: "権限と利用条件を確認してください。"
    }
  }

  private var transcriptionCapabilityDetail: String {
    if let failure = capture.lastTranscriptionFailure { return failureDescription(failure) }
    return capture.state == .running ? "動作中 · 端末上で処理" : "iOS 26のSpeech Recognitionを使用"
  }

  private var intelligenceDetail: String {
    switch meeting.state {
    case .intelligenceUnavailable: "Apple Intelligenceが利用できません"
    case .failed: "要約の生成に失敗しました"
    case .updating: "会議Contextを更新中"
    case .ready: "決定・TODO・質問を更新済み"
    case .empty: "確定した発話を待っています"
    case .sourceDisabled: "Audio Context SourceがOFFです"
    case .stopped, .listening: "30秒ごとに決定・TODO・質問を更新"
    }
  }

  private func failureDescription(_ failure: TranscriptionFailure) -> String {
    switch failure {
    case .unsupportedOperatingSystem: "Live文字起こしにはiOS 26以降が必要です。"
    case .speechPermissionDenied: "マイクまたは音声認識の権限が許可されていません。"
    case .unsupportedLocale: "この言語は端末の音声認識に対応していません。"
    case .assetsUnavailable: "日本語の音声認識モデルを準備できませんでした。"
    case .invalidAudio: "マイクの音声形式または音声セッションを開始できませんでした。"
    case .analysisFailed: "音声解析が停止しました。もう一度開始してください。"
    }
  }
}
