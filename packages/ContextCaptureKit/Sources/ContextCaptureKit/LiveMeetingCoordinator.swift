import Foundation
import Observation

public enum LiveMeetingCaptureState: Equatable, Sendable {
  case stopped
  case starting
  case running
  case stopping
  case unavailable
}

@MainActor
@Observable
public final class LiveMeetingCoordinator {
  public private(set) var state: LiveMeetingCaptureState = .stopped
  public private(set) var sessionID: String?
  public private(set) var startedAt: Date?
  public private(set) var transcript = TranscriptBuffer()
  public private(set) var persistedEventCount = 0
  public private(set) var lastTranscriptionFailure: TranscriptionFailure?
  public private(set) var lastEventFailure: TranscriptEventPipelineFailure?

  private let speech: any LiveSpeechStreaming
  private let eventPipeline: TranscriptEventPipeline?
  private let locale: Locale
  private let now: @MainActor @Sendable () -> Date
  private let makeSessionID: @MainActor @Sendable () -> String
  private var consumptionTask: Task<Void, Never>?

  public init(
    speech: any LiveSpeechStreaming,
    eventPipeline: TranscriptEventPipeline? = nil,
    locale: Locale = Locale(identifier: "ja-JP"),
    now: @escaping @MainActor @Sendable () -> Date = Date.init,
    makeSessionID: @escaping @MainActor @Sendable () -> String = {
      UUID().uuidString.lowercased()
    }
  ) {
    self.speech = speech
    self.eventPipeline = eventPipeline
    self.locale = locale
    self.now = now
    self.makeSessionID = makeSessionID
  }

  public func toggle() async {
    switch state {
    case .stopped, .unavailable:
      await start()
    case .running:
      await stop()
    case .starting, .stopping:
      break
    }
  }

  public func start() async {
    guard state == .stopped || state == .unavailable else { return }
    state = .starting
    lastTranscriptionFailure = nil
    lastEventFailure = nil
    let candidateSessionID = makeSessionID()
    let candidateStartedAt = now()
    do {
      let segments = try await speech.start(locale: locale)
      sessionID = candidateSessionID
      startedAt = candidateStartedAt
      transcript = TranscriptBuffer()
      persistedEventCount = 0
      state = .running
      consumptionTask = consume(
        segments,
        sessionID: candidateSessionID,
        startedAt: candidateStartedAt
      )
    } catch let failure as TranscriptionFailure {
      failStart(with: failure)
    } catch {
      failStart(with: .analysisFailed)
    }
  }

  public func stop() async {
    guard state == .running else { return }
    state = .stopping
    await speech.stop()
    await consumptionTask?.value
    consumptionTask = nil
    state = .stopped
  }

  private func consume(
    _ segments: AsyncThrowingStream<TranscriptionSegment, Error>,
    sessionID: String,
    startedAt: Date
  ) -> Task<Void, Never> {
    Task { [weak self] in
      do {
        for try await segment in segments {
          guard let self else { return }
          guard self.transcript.ingest(segment, sourceID: sessionID) else { continue }
          await self.persist(segment, sessionID: sessionID, startedAt: startedAt)
        }
      } catch let failure as TranscriptionFailure {
        self?.lastTranscriptionFailure = failure
        self?.state = .unavailable
      } catch is CancellationError {
        return
      } catch {
        self?.lastTranscriptionFailure = .analysisFailed
        self?.state = .unavailable
      }
    }
  }

  private func persist(
    _ segment: TranscriptionSegment,
    sessionID: String,
    startedAt: Date
  ) async {
    guard segment.isFinal, let eventPipeline else { return }
    do {
      _ = try await eventPipeline.process(
        segment,
        chunkStartedAt: startedAt,
        sessionID: sessionID
      )
      persistedEventCount += 1
      lastEventFailure = nil
    } catch let failure as TranscriptEventPipelineFailure {
      lastEventFailure = failure
    } catch {
      lastEventFailure = .persistenceFailed
    }
  }

  private func failStart(with failure: TranscriptionFailure) {
    state = .unavailable
    sessionID = nil
    startedAt = nil
    lastTranscriptionFailure = failure
  }
}
