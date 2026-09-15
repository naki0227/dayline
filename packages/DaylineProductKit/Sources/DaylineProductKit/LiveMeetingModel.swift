import ContextCoreKit
import Foundation
import Observation

public enum LiveMeetingLoadState: Equatable, Sendable {
  case stopped
  case listening
  case updating
  case ready
  case empty
  case sourceDisabled
  case intelligenceUnavailable
  case failed
}

@MainActor
@Observable
public final class LiveMeetingModel {
  public private(set) var state: LiveMeetingLoadState = .stopped
  public private(set) var latest: SemanticArtifactDocument?

  public var presentation: ArtifactPresentation? {
    latest.map(ArtifactPresentation.init)
  }

  private let generator: any LiveMeetingGenerating
  private let sleep: @Sendable (Duration) async throws -> Void
  private var sessionID: String?
  private var startedAt: Date?
  private var timezone: TimeZone = .current
  private var language = "ja"
  private var updateTask: Task<Void, Never>?

  public init(
    generator: any LiveMeetingGenerating,
    sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
      try await Task.sleep(for: duration)
    }
  ) {
    self.generator = generator
    self.sleep = sleep
  }

  public func begin(
    sessionID: String,
    startedAt: Date,
    timezone: TimeZone = .current,
    language: String = "ja"
  ) {
    updateTask?.cancel()
    self.sessionID = sessionID
    self.startedAt = startedAt
    self.timezone = timezone
    self.language = language
    latest = nil
    state = .listening
    updateTask = scheduleUpdates()
  }

  public func end() async {
    updateTask?.cancel()
    updateTask = nil
    if sessionID != nil, startedAt != nil {
      await refresh()
    }
    state = .stopped
    sessionID = nil
    startedAt = nil
  }

  public func refresh() async {
    guard let sessionID, let startedAt else { return }
    state = .updating
    do {
      latest = try await generator.generate(
        sessionID: sessionID,
        startedAt: startedAt,
        timezone: timezone,
        language: language
      )
      state = .ready
    } catch LiveMeetingFailure.emptyContext {
      state = .empty
    } catch LiveMeetingFailure.sourceDisabled {
      state = .sourceDisabled
    } catch LiveMeetingFailure.generationUnavailable {
      state = .intelligenceUnavailable
    } catch {
      state = .failed
    }
  }

  private func scheduleUpdates() -> Task<Void, Never> {
    let interval = Duration.seconds(generator.updateIntervalSeconds)
    return Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await self?.sleep(interval)
        } catch {
          return
        }
        guard !Task.isCancelled, let self else { return }
        await self.refresh()
      }
    }
  }
}
