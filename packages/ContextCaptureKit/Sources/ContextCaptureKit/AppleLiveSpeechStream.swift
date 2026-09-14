#if os(iOS)
  import AVFAudio
  import CoreMedia
  import Foundation
  import Speech

  @MainActor
  @available(iOS 26.0, *)
  public final class AppleLiveSpeechStream: LiveSpeechStreaming {
    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation?
    private var resultContinuation: AsyncThrowingStream<TranscriptionSegment, Error>.Continuation?
    private var resultTask: Task<Void, Never>?
    private var hasInputTap = false

    public init() {}

    public func start(
      locale: Locale
    ) async throws -> AsyncThrowingStream<TranscriptionSegment, Error> {
      guard analyzer == nil else { throw TranscriptionFailure.analysisFailed }
      guard await AVAudioApplication.requestRecordPermission() else {
        throw TranscriptionFailure.speechPermissionDenied
      }

      let setup = try await makeSetup(locale: locale)

      do {
        try configureAudioSession()
        try await setup.analyzer.prepareToAnalyze(in: setup.analyzerFormat)
        try await setup.analyzer.start(inputSequence: setup.inputs)
        try installInputTap(
          analyzerFormat: setup.analyzerFormat,
          continuation: setup.inputContinuation
        )
        engine.prepare()
        try engine.start()
      } catch let failure as TranscriptionFailure {
        await cancelSetup(setup)
        throw failure
      } catch {
        await cancelSetup(setup)
        throw TranscriptionFailure.analysisFailed
      }

      analyzer = setup.analyzer
      inputContinuation = setup.inputContinuation
      resultContinuation = setup.resultContinuation
      resultTask = setup.resultTask
      return setup.results
    }

    public func stop() async {
      engine.stop()
      removeInputTap()
      inputContinuation?.finish()
      do {
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
      } catch {
        resultContinuation?.finish(throwing: TranscriptionFailure.analysisFailed)
      }
      await resultTask?.value
      reset()
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: .notifyOthersOnDeactivation
      )
    }

    private func makeResultTask(
      transcriber: SpeechTranscriber,
      locale: Locale,
      continuation: AsyncThrowingStream<TranscriptionSegment, Error>.Continuation
    ) -> Task<Void, Never> {
      Task {
        do {
          for try await result in transcriber.results {
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
    }

    private func makeSetup(locale: Locale) async throws -> LiveSpeechSetup {
      let (transcriber, supportedLocale) = try await AppleSpeechSupport.makeTranscriber(
        locale: locale,
        preset: .progressiveTranscription
      )
      let modules: [any SpeechModule] = [transcriber]
      guard
        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
          compatibleWith: modules
        )
      else {
        throw TranscriptionFailure.invalidAudio
      }
      let (inputs, inputContinuation) = AsyncThrowingStream.makeStream(
        of: AnalyzerInput.self
      )
      let (results, resultContinuation) = AsyncThrowingStream.makeStream(
        of: TranscriptionSegment.self
      )
      return LiveSpeechSetup(
        analyzer: SpeechAnalyzer(modules: modules),
        analyzerFormat: analyzerFormat,
        inputs: inputs,
        inputContinuation: inputContinuation,
        results: results,
        resultContinuation: resultContinuation,
        resultTask: makeResultTask(
          transcriber: transcriber,
          locale: supportedLocale,
          continuation: resultContinuation
        )
      )
    }

    private func configureAudioSession() throws {
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
          .record,
          mode: .spokenAudio,
          options: [.allowBluetoothHFP]
        )
        try session.setActive(true)
      } catch {
        throw TranscriptionFailure.invalidAudio
      }
    }

    private func installInputTap(
      analyzerFormat: AVAudioFormat,
      continuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation
    ) throws {
      let input = engine.inputNode
      let sourceFormat = input.outputFormat(forBus: 0)
      let sink = try LiveAnalyzerInputSink(
        sourceFormat: sourceFormat,
        destinationFormat: analyzerFormat,
        continuation: continuation
      )
      input.installTap(
        onBus: 0,
        bufferSize: 4_096,
        format: sourceFormat
      ) { buffer, _ in
        sink.receive(buffer)
      }
      hasInputTap = true
    }

    private func cancelSetup(_ setup: LiveSpeechSetup) async {
      engine.stop()
      removeInputTap()
      setup.inputContinuation.finish()
      await setup.analyzer.cancelAndFinishNow()
      setup.resultTask.cancel()
      setup.resultContinuation.finish(throwing: TranscriptionFailure.analysisFailed)
    }

    private func removeInputTap() {
      guard hasInputTap else { return }
      engine.inputNode.removeTap(onBus: 0)
      hasInputTap = false
    }

    private func reset() {
      analyzer = nil
      inputContinuation = nil
      resultContinuation = nil
      resultTask = nil
    }
  }

  @available(iOS 26.0, *)
  private struct LiveSpeechSetup {
    let analyzer: SpeechAnalyzer
    let analyzerFormat: AVAudioFormat
    let inputs: AsyncThrowingStream<AnalyzerInput, Error>
    let inputContinuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation
    let results: AsyncThrowingStream<TranscriptionSegment, Error>
    let resultContinuation: AsyncThrowingStream<TranscriptionSegment, Error>.Continuation
    let resultTask: Task<Void, Never>
  }

  @available(iOS 26.0, *)
  private final class LiveAnalyzerInputSink: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let destinationFormat: AVAudioFormat
    private let continuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation
    private let lock = NSLock()

    init(
      sourceFormat: AVAudioFormat,
      destinationFormat: AVAudioFormat,
      continuation: AsyncThrowingStream<AnalyzerInput, Error>.Continuation
    ) throws {
      guard let converter = AVAudioConverter(from: sourceFormat, to: destinationFormat) else {
        throw TranscriptionFailure.invalidAudio
      }
      self.converter = converter
      self.destinationFormat = destinationFormat
      self.continuation = continuation
    }

    func receive(_ buffer: AVAudioPCMBuffer) {
      lock.lock()
      defer { lock.unlock() }
      let ratio = destinationFormat.sampleRate / buffer.format.sampleRate
      let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
      guard
        capacity > 0,
        let converted = AVAudioPCMBuffer(
          pcmFormat: destinationFormat,
          frameCapacity: capacity
        )
      else {
        continuation.finish(throwing: TranscriptionFailure.invalidAudio)
        return
      }
      do {
        try converter.convert(to: converted, from: buffer)
        continuation.yield(AnalyzerInput(buffer: converted))
      } catch {
        continuation.finish(throwing: TranscriptionFailure.invalidAudio)
      }
    }
  }
#endif
