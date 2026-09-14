import ContextCaptureKit
import ContextCoreFFIKit
import ContextCoreKit
import Foundation

typealias AppContextStore = ContextEventPersisting & StoredContextBuilding
  & SemanticArtifactPersisting

@MainActor
enum AppCaptureEnvironment {
  static func makeCoordinator(
    processInfo: ProcessInfo = .processInfo,
    eventStore: any ContextEventPersisting
  ) -> CaptureCoordinator {
    if processInfo.arguments.contains("--ui-testing") {
      return CaptureCoordinator(
        recorder: DeterministicAudioRecorder(),
        automaticChunkDuration: nil
      )
    }
    let pipeline = makeTranscriptEventPipeline(eventStore: eventStore)
    return CaptureCoordinator(
      recorder: AVAudioRecorderAdapter(),
      transcriber: AppleSpeechFileTranscriber(),
      transcriptEventPipeline: pipeline
    )
  }

  private static func makeTranscriptEventPipeline(
    eventStore: any ContextEventPersisting
  ) -> TranscriptEventPipeline? {
    guard
      let mapper = TranscriptEventMapper(
        timezoneIdentifier: TimeZone.current.identifier,
        deviceID: installationID()
      )
    else { return nil }
    return TranscriptEventPipeline(mapper: mapper, store: eventStore)
  }

  static func makeContextStore(
    fileManager: FileManager = .default
  ) -> any AppContextStore {
    guard
      let applicationSupport = fileManager.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
    else { return UnavailableContextStore() }
    let directory = applicationSupport.appendingPathComponent("Dayline", isDirectory: true)
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      return RustContextStore(
        databaseURL: directory.appendingPathComponent("context.sqlite")
      )
    } catch {
      return UnavailableContextStore()
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

private struct UnavailableContextStore: ContextEventPersisting {
  func persist(
    _: TextContextEventDocument
  ) async throws -> TextContextEventDocument {
    throw LocalContextStoreFailure.unavailable
  }

  func buildStoredContext(
    _: StoredContextRequestDocument
  ) async throws -> ContextBundleDocument {
    throw LocalContextStoreFailure.unavailable
  }

  func persist(
    _: SemanticArtifactDocument
  ) async throws -> SemanticArtifactDocument {
    throw LocalContextStoreFailure.unavailable
  }
}

extension UnavailableContextStore: StoredContextBuilding {}
extension UnavailableContextStore: SemanticArtifactPersisting {}

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
