import Foundation

@MainActor
protocol RecordingAudioSessionControlling: AnyObject {
  func configureForRecording() throws
  func activate() throws
  func deactivate()
}

@MainActor
final class RecordingAudioSessionLifecycle {
  private let session: any RecordingAudioSessionControlling

  init(session: any RecordingAudioSessionControlling) {
    self.session = session
  }

  func prepare() throws {
    do {
      try session.configureForRecording()
    } catch {
      session.deactivate()
      throw CaptureFailure.audioSessionConfigurationFailed
    }

    do {
      try session.activate()
    } catch {
      session.deactivate()
      throw CaptureFailure.audioSessionActivationFailed
    }
  }

  func deactivate() {
    session.deactivate()
  }
}
