import Foundation

public struct TranscriptionSegment: Equatable, Sendable {
  public let text: String
  public let localeIdentifier: String
  public let startTime: TimeInterval
  public let duration: TimeInterval
  public let isFinal: Bool

  public init(
    text: String,
    localeIdentifier: String,
    startTime: TimeInterval,
    duration: TimeInterval,
    isFinal: Bool
  ) {
    self.text = text
    self.localeIdentifier = localeIdentifier
    self.startTime = startTime
    self.duration = duration
    self.isFinal = isFinal
  }
}

public enum TranscriptionFailure: Error, Equatable, Sendable {
  case unsupportedOperatingSystem
  case speechPermissionDenied
  case unsupportedLocale
  case assetsUnavailable
  case invalidAudio
  case analysisFailed
}

public protocol SpeechTranscribing: Sendable {
  func segments(
    for audioFileURL: URL,
    locale: Locale
  ) async throws -> AsyncThrowingStream<TranscriptionSegment, Error>
}

@MainActor
public protocol LiveSpeechStreaming: Sendable {
  func start(
    locale: Locale
  ) async throws -> AsyncThrowingStream<TranscriptionSegment, Error>

  func stop() async
}
