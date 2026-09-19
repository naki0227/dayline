import Foundation

public enum DailyCaptureState: Equatable, Sendable {
  case stopped
  case starting
  case running
  case stopping
}

public enum AudioSourceState: Equatable, Sendable {
  case stopped
  case waitingForAudio
  case recording
  case interrupted
  case unavailable
}

public enum CaptureFailure: Error, Equatable, Sendable {
  case microphonePermissionDenied
  case audioSessionConfigurationFailed
  case audioSessionActivationFailed
  case audioTemporarilyUnavailable
  case storageUnavailable
  case recordingFailed
}

public struct CaptureSnapshot: Equatable, Sendable {
  public let daily: DailyCaptureState
  public let audio: AudioSourceState
  public let activeFileURL: URL?
  public let startedAt: Date?
  public let lastFailure: CaptureFailure?
}
