import ContextCaptureKit
import Foundation

@MainActor
enum AppCaptureEnvironment {
  static func makeCoordinator(
    processInfo: ProcessInfo = .processInfo
  ) -> CaptureCoordinator {
    if processInfo.arguments.contains("--ui-testing") {
      return CaptureCoordinator(
        recorder: DeterministicAudioRecorder(),
        automaticChunkDuration: nil
      )
    }
    return CaptureCoordinator(recorder: AVAudioRecorderAdapter())
  }
}

@MainActor
private final class DeterministicAudioRecorder: AudioRecording {
  func startChunk() async throws -> URL {
    URL(filePath: "/tmp/dayline-ui-test.m4a")
  }

  func stopChunk() async {}
}
