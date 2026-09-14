import ContextCaptureKit
import ContextCoreKit
import SwiftUI

struct RootView: View {
  @Bindable var capture: CaptureCoordinator

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        statusCard
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
      Task { await capture.toggle() }
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
