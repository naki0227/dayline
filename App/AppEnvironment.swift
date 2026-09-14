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

  static func make(processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
    let store = AppCaptureEnvironment.makeContextStore()
    if processInfo.arguments.contains("--ui-testing") {
      return AppEnvironment(
        capture: AppCaptureEnvironment.makeCoordinator(
          processInfo: processInfo,
          eventStore: store
        ),
        dailySummary: DailySummaryModel(generator: EmptyDailySummaryGenerator())
      )
    }
    let bridge = RustContextBridge()
    let reducer = ContextReducer { context, maximumUnits in
      try bridge.shrinkContext(context, maximumUnits: maximumUnits)
    }
    let service = DailySummaryService(
      contextBuilder: store,
      runtime: AppleFoundationModelRuntime(reducer: reducer),
      artifactStore: store
    )
    return AppEnvironment(
      capture: AppCaptureEnvironment.makeCoordinator(
        processInfo: processInfo,
        eventStore: store
      ),
      dailySummary: DailySummaryModel(generator: service)
    )
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
