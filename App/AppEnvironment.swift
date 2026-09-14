import AppleIntelligenceKit
import ContextCaptureKit
import ContextCoreFFIKit
import ContextCoreKit
import DaylineProductKit
import Foundation

@MainActor
struct AppEnvironment {
  let capture: CaptureCoordinator
  let dailySummary: DailySummaryModel
  let liveCapture: LiveMeetingCoordinator
  let liveMeeting: LiveMeetingModel

  static func make(processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
    let store = AppCaptureEnvironment.makeContextStore()
    if processInfo.arguments.contains("--ui-testing") {
      return AppEnvironment(
        capture: AppCaptureEnvironment.makeCoordinator(
          processInfo: processInfo,
          eventStore: store
        ),
        dailySummary: DailySummaryModel(generator: EmptyDailySummaryGenerator()),
        liveCapture: AppCaptureEnvironment.makeLiveMeetingCoordinator(
          processInfo: processInfo,
          eventStore: store
        ),
        liveMeeting: LiveMeetingModel(generator: EmptyLiveMeetingGenerator())
      )
    }
    let bridge = RustContextBridge()
    let reducer = ContextReducer { context, maximumUnits in
      try bridge.shrinkContext(context, maximumUnits: maximumUnits)
    }
    let dailyService = DailySummaryService(
      contextBuilder: store,
      runtime: AppleFoundationModelRuntime(reducer: reducer),
      artifactStore: store
    )
    let liveGenerator: any LiveMeetingGenerating
    do {
      liveGenerator = try LiveMeetingService(
        contextBuilder: store,
        runtime: AppleFoundationModelRuntime(reducer: reducer),
        artifactStore: store
      )
    } catch {
      liveGenerator = UnavailableLiveMeetingGenerator()
    }
    return AppEnvironment(
      capture: AppCaptureEnvironment.makeCoordinator(
        processInfo: processInfo,
        eventStore: store
      ),
      dailySummary: DailySummaryModel(generator: dailyService),
      liveCapture: AppCaptureEnvironment.makeLiveMeetingCoordinator(
        processInfo: processInfo,
        eventStore: store
      ),
      liveMeeting: LiveMeetingModel(generator: liveGenerator)
    )
  }
}

private struct EmptyLiveMeetingGenerator: LiveMeetingGenerating {
  let updateIntervalSeconds: UInt16 = 30

  func generate(
    sessionID _: String,
    startedAt _: Date,
    timezone _: TimeZone,
    language _: String
  ) async throws -> SemanticArtifactDocument {
    throw LiveMeetingFailure.emptyContext
  }
}

private struct UnavailableLiveMeetingGenerator: LiveMeetingGenerating {
  let updateIntervalSeconds: UInt16 = 30

  func generate(
    sessionID _: String,
    startedAt _: Date,
    timezone _: TimeZone,
    language _: String
  ) async throws -> SemanticArtifactDocument {
    throw LiveMeetingFailure.invalidProfile
  }
}

private struct EmptyDailySummaryGenerator: DailySummaryGenerating {
  func generate(
    for _: Date,
    timezone _: TimeZone,
    language _: String
  ) async throws -> SemanticArtifactDocument {
    throw DailySummaryFailure.emptyContext
  }
}
