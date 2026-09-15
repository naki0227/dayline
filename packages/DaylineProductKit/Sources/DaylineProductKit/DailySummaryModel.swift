import ContextCoreKit
import Foundation
import Observation

public enum DailySummaryLoadState: Equatable, Sendable {
  case idle
  case generating
  case ready
  case empty
  case intelligenceUnavailable
  case failed
}

@MainActor
@Observable
public final class DailySummaryModel {
  public private(set) var state: DailySummaryLoadState = .idle
  public private(set) var summary: SemanticArtifactDocument?

  public var presentation: ArtifactPresentation? {
    summary.map(ArtifactPresentation.init)
  }

  private let generator: any DailySummaryGenerating

  public init(generator: any DailySummaryGenerating) {
    self.generator = generator
  }

  public func generate(
    for date: Date = Date(),
    timezone: TimeZone = .current,
    language: String = "ja"
  ) async {
    guard state != .generating else { return }
    state = .generating
    do {
      summary = try await generator.generate(
        for: date,
        timezone: timezone,
        language: language
      )
      state = .ready
    } catch DailySummaryFailure.emptyContext {
      state = .empty
    } catch DailySummaryFailure.generationUnavailable {
      state = .intelligenceUnavailable
    } catch {
      state = .failed
    }
  }
}
