import AVFAudio
import AppleIntelligenceKit
import EventKit
import Foundation
import Observation
import Speech
import UserNotifications

enum AppCapabilityState: Equatable {
  case available
  case permissionNeeded
  case denied
  case preparing
  case deviceNotEligible
  case unsupportedOperatingSystem
}

enum AppCapability: String, CaseIterable, Identifiable {
  case microphone
  case speechRecognition
  case appleIntelligence
  case notifications
  case calendar
  case backgroundAudio

  var id: String { rawValue }
}

@MainActor
@Observable
final class AppCapabilityModel {
  private(set) var states: [AppCapability: AppCapabilityState] = [:]
  private let processInfo: ProcessInfo

  init(processInfo: ProcessInfo = .processInfo) {
    self.processInfo = processInfo
  }

  func refresh() async {
    if processInfo.arguments.contains("--ui-testing") {
      states = Dictionary(uniqueKeysWithValues: AppCapability.allCases.map { ($0, .available) })
      return
    }
    states[.microphone] = microphoneState
    states[.speechRecognition] = authorizationState(SFSpeechRecognizer.authorizationStatus())
    states[.appleIntelligence] = intelligenceState
    states[.calendar] = calendarState
    states[.backgroundAudio] = .available

    let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
    states[.notifications] = notificationState(notificationSettings.authorizationStatus)
  }

  func request(_ capability: AppCapability) async {
    switch capability {
    case .microphone:
      _ = await AVAudioApplication.requestRecordPermission()
    case .speechRecognition:
      _ = await requestSpeechAuthorization()
    case .notifications:
      _ = try? await UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert, .badge, .sound]
      )
    case .calendar:
      _ = try? await EKEventStore().requestFullAccessToEvents()
    case .appleIntelligence, .backgroundAudio:
      break
    }
    await refresh()
  }

  func state(for capability: AppCapability) -> AppCapabilityState {
    states[capability] ?? .permissionNeeded
  }

  private var microphoneState: AppCapabilityState {
    switch AVAudioApplication.shared.recordPermission {
    case .granted: .available
    case .denied: .denied
    case .undetermined: .permissionNeeded
    @unknown default: .permissionNeeded
    }
  }

  private var intelligenceState: AppCapabilityState {
    switch SystemIntelligenceAvailability.current() {
    case .available: .available
    case .unsupportedOperatingSystem: .unsupportedOperatingSystem
    case .unavailable(.deviceNotEligible): .deviceNotEligible
    case .unavailable(.appleIntelligenceNotEnabled), .unavailable(.modelNotReady): .preparing
    }
  }

  private var calendarState: AppCapabilityState {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .fullAccess, .writeOnly, .authorized: .available
    case .denied, .restricted: .denied
    case .notDetermined: .permissionNeeded
    @unknown default: .permissionNeeded
    }
  }

  private func authorizationState(
    _ status: SFSpeechRecognizerAuthorizationStatus
  ) -> AppCapabilityState {
    switch status {
    case .authorized: .available
    case .denied, .restricted: .denied
    case .notDetermined: .permissionNeeded
    @unknown default: .permissionNeeded
    }
  }

  private func notificationState(_ status: UNAuthorizationStatus) -> AppCapabilityState {
    switch status {
    case .authorized, .provisional, .ephemeral: .available
    case .denied: .denied
    case .notDetermined: .permissionNeeded
    @unknown default: .permissionNeeded
    }
  }

  private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
  }
}
