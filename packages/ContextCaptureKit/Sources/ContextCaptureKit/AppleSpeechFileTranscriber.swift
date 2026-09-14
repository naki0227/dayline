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
      let (transcriber, supportedLocale) = try await AppleSpeechSupport.makeTranscriber(
        locale: locale,
        preset: .progressiveTranscription
      )
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

  }
#endif
