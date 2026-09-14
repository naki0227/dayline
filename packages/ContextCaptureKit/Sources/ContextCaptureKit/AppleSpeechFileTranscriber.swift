#if os(iOS)
  import AVFAudio
  import CoreMedia
  import Foundation
  import Speech

  public struct AppleSpeechFileTranscriber: SpeechTranscribing {
    public init() {}

    public func segments(
      for audioFileURL: URL,
      locale: Locale
    ) async throws -> AsyncThrowingStream<TranscriptionSegment, Error> {
      guard #available(iOS 26.0, *) else {
        throw TranscriptionFailure.unsupportedOperatingSystem
      }
      try await requestPermission()
      guard SpeechTranscriber.isAvailable else {
        throw TranscriptionFailure.assetsUnavailable
      }
      guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
      else {
        throw TranscriptionFailure.unsupportedLocale
      }

      let transcriber = SpeechTranscriber(
        locale: supportedLocale,
        preset: .progressiveTranscription
      )
      try await prepareAssets(for: transcriber)
      let audioFile: AVAudioFile
      do {
        audioFile = try AVAudioFile(forReading: audioFileURL)
      } catch {
        throw TranscriptionFailure.invalidAudio
      }

      return makeStream(
        audioFile: audioFile,
        transcriber: transcriber,
        locale: supportedLocale
      )
    }

    @available(iOS 26.0, *)
    private func makeStream(
      audioFile: AVAudioFile,
      transcriber: SpeechTranscriber,
      locale: Locale
    ) -> AsyncThrowingStream<TranscriptionSegment, Error> {
      let analyzer = SpeechAnalyzer(modules: [transcriber])
      return AsyncThrowingStream { continuation in
        let task = Task {
          do {
            try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
            for try await result in transcriber.results {
              try Task.checkCancellation()
              continuation.yield(
                TranscriptionSegment(
                  text: String(result.text.characters),
                  localeIdentifier: locale.identifier,
                  startTime: CMTimeGetSeconds(result.range.start),
                  duration: CMTimeGetSeconds(result.range.duration),
                  isFinal: result.isFinal
                )
              )
            }
            continuation.finish()
          } catch is CancellationError {
            continuation.finish()
          } catch {
            continuation.finish(throwing: TranscriptionFailure.analysisFailed)
          }
        }
        continuation.onTermination = { _ in task.cancel() }
      }
    }

    @available(iOS 26.0, *)
    private func prepareAssets(for transcriber: SpeechTranscriber) async throws {
      let modules: [any SpeechModule] = [transcriber]
      let status = await AssetInventory.status(forModules: modules)
      switch status {
      case .installed:
        return
      case .supported, .downloading:
        do {
          if let request = try await AssetInventory.assetInstallationRequest(
            supporting: modules
          ) {
            try await request.downloadAndInstall()
          }
        } catch {
          throw TranscriptionFailure.assetsUnavailable
        }
      case .unsupported:
        throw TranscriptionFailure.assetsUnavailable
      @unknown default:
        throw TranscriptionFailure.assetsUnavailable
      }
    }

    private func requestPermission() async throws {
      let status = await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
          continuation.resume(returning: status)
        }
      }
      guard status == .authorized else {
        throw TranscriptionFailure.speechPermissionDenied
      }
    }
  }
#endif
