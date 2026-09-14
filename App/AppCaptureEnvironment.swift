import ContextCaptureKit
import ContextCoreFFIKit
import ContextCoreKit
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
    let pipeline = makeTranscriptEventPipeline()
    return CaptureCoordinator(
      recorder: AVAudioRecorderAdapter(),
      transcriber: AppleSpeechFileTranscriber(),
      transcriptEventPipeline: pipeline
    )
  }

  private static func makeTranscriptEventPipeline() -> TranscriptEventPipeline? {
    guard
      let mapper = TranscriptEventMapper(
        timezoneIdentifier: TimeZone.current.identifier,
        deviceID: installationID()
      )
    else { return nil }
    return TranscriptEventPipeline(mapper: mapper, store: makeEventStore())
  }

  private static func makeEventStore(
    fileManager: FileManager = .default
  ) -> any ContextEventPersisting {
    guard
      let applicationSupport = fileManager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else { return UnavailableContextEventStore() }
    let directory = applicationSupport.appendingPathComponent("Dayline", isDirectory: true)
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      return RustContextEventStore(
        databaseURL: directory.appendingPathComponent("context.sqlite")
      )
    } catch {
      return UnavailableContextEventStore()
    }
  }

  private static func installationID(
    defaults: UserDefaults = .standard
  ) -> String {
    let key = "dayline.installation-id"
    if let existing = defaults.string(forKey: key), !existing.isEmpty {
      return existing
    }
    let created = UUID().uuidString.lowercased()
    defaults.set(created, forKey: key)
    return created
  }
}

private struct UnavailableContextEventStore: ContextEventPersisting {
  func persist(
    _: TextContextEventDocument
  ) async throws -> TextContextEventDocument {
    throw LocalContextStoreFailure.unavailable
  }
}

private enum LocalContextStoreFailure: Error {
  case unavailable
}

@MainActor
private final class DeterministicAudioRecorder: AudioRecording {
  func startChunk() async throws -> URL {
    URL(filePath: "/tmp/dayline-ui-test.m4a")
  }

  func stopChunk() async {}
}
