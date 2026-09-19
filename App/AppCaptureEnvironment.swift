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
      let recorder: any AudioRecording =
        if processInfo.arguments.contains("--ui-testing-audio-waiting") {
          DeterministicWaitingAudioRecorder()
        } else {
          DeterministicAudioRecorder()
        }
      return CaptureCoordinator(
        recorder: recorder,
        automaticChunkDuration: nil,
        audioRecoveryInterval: nil
      )
    }
    let pipeline = makeTranscriptEventPipeline(eventStore: eventStore)
    return CaptureCoordinator(
      recorder: AVAudioRecorderAdapter(),
      transcriber: AppleSpeechFileTranscriber(),
      transcriptEventPipeline: pipeline
    )
  }

  static func makeLiveMeetingCoordinator(
    processInfo: ProcessInfo = .processInfo,
    eventStore: any ContextEventPersisting
  ) -> LiveMeetingCoordinator {
    let speech: any LiveSpeechStreaming
    if processInfo.arguments.contains("--ui-testing") {
      speech = DeterministicLiveSpeechStream()
    } else if #available(iOS 26.0, *) {
      speech = AppleLiveSpeechStream()
    } else {
      speech = UnavailableLiveSpeechStream()
    }
    return LiveMeetingCoordinator(
      speech: speech,
      eventPipeline: makeTranscriptEventPipeline(eventStore: eventStore)
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
private final class DeterministicLiveSpeechStream: LiveSpeechStreaming {
  private var continuation: AsyncThrowingStream<TranscriptionSegment, Error>.Continuation?

  func start(
    locale _: Locale
  ) async -> AsyncThrowingStream<TranscriptionSegment, Error> {
    AsyncThrowingStream { continuation in
      self.continuation = continuation
    }
  }

  func stop() async {
    continuation?.finish()
    continuation = nil
  }
}

@MainActor
private struct UnavailableLiveSpeechStream: LiveSpeechStreaming {
  func start(
    locale _: Locale
  ) async throws -> AsyncThrowingStream<TranscriptionSegment, Error> {
    throw TranscriptionFailure.unsupportedOperatingSystem
  }

  func stop() async {}
}

@MainActor
private final class DeterministicAudioRecorder: AudioRecording {
  func startChunk() async throws -> URL {
    URL(filePath: "/tmp/dayline-ui-test.m4a")
  }

  func stopChunk() async {}
}

@MainActor
private final class DeterministicWaitingAudioRecorder: AudioRecording {
  func startChunk() async throws -> URL {
    throw CaptureFailure.audioTemporarilyUnavailable
  }

  func stopChunk() async {}
}
