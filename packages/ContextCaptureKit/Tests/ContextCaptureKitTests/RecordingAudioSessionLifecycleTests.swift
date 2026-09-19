import Foundation
import Testing

@testable import ContextCaptureKit

@MainActor
private final class AudioSessionFake: RecordingAudioSessionControlling {
  enum Failure: Error {
    case expected
  }

  var configurationResult: Result<Void, Failure> = .success(())
  var activationResult: Result<Void, Failure> = .success(())
  private(set) var configureCount = 0
  private(set) var activateCount = 0
  private(set) var deactivateCount = 0

  func configureForRecording() throws {
    configureCount += 1
    try configurationResult.get()
  }

  func activate() throws {
    activateCount += 1
    try activationResult.get()
  }

  func deactivate() {
    deactivateCount += 1
  }
}

@MainActor
@Test
func preparesRecordingAudioSessionInOrder() throws {
  let session = AudioSessionFake()
  let lifecycle = RecordingAudioSessionLifecycle(session: session)

  try lifecycle.prepare()

  #expect(session.configureCount == 1)
  #expect(session.activateCount == 1)
  #expect(session.deactivateCount == 0)
}

@MainActor
@Test
func configurationFailureIsSpecificAndCleansUp() {
  let session = AudioSessionFake()
  session.configurationResult = .failure(.expected)
  let lifecycle = RecordingAudioSessionLifecycle(session: session)

  #expect(throws: CaptureFailure.audioSessionConfigurationFailed) {
    try lifecycle.prepare()
  }
  #expect(session.activateCount == 0)
  #expect(session.deactivateCount == 1)
}

@MainActor
@Test
func activationFailureIsSpecificAndCleansUp() {
  let session = AudioSessionFake()
  session.activationResult = .failure(.expected)
  let lifecycle = RecordingAudioSessionLifecycle(session: session)

  #expect(throws: CaptureFailure.audioSessionActivationFailed) {
    try lifecycle.prepare()
  }
  #expect(session.activateCount == 1)
  #expect(session.deactivateCount == 1)
}
