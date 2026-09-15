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
  let sourcePolicyStore: DaylineSourcePolicyStore
  let sourcePolicyPersistence: AppSourcePolicyPersistence
  let initialSourcePolicy: DaylineSourcePolicy

  static func make(processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
    let store = AppCaptureEnvironment.makeContextStore()
    let persistence = AppSourcePolicyPersistence()
    let isUITesting = processInfo.arguments.contains("--ui-testing")
    let initialPolicy = isUITesting ? DaylineSourcePolicy.localDefault : persistence.load()
    let sourcePolicyStore = DaylineSourcePolicyStore(policy: initialPolicy)
    if isUITesting {
      return makeUITest(
        processInfo: processInfo,
        store: store,
        policyStore: sourcePolicyStore,
        persistence: persistence,
        initialPolicy: initialPolicy
      )
    }
    return makeProduction(
      processInfo: processInfo,
      store: store,
      policyStore: sourcePolicyStore,
      persistence: persistence,
      initialPolicy: initialPolicy
    )
  }

  private static func makeProduction(
    processInfo: ProcessInfo,
    store: any AppContextStore,
    policyStore: DaylineSourcePolicyStore,
    persistence: AppSourcePolicyPersistence,
    initialPolicy: DaylineSourcePolicy
  ) -> AppEnvironment {
    let bridge = RustContextBridge()
    let reducer = ContextReducer { context, maximumUnits in
      try bridge.shrinkContext(context, maximumUnits: maximumUnits)
    }
    let dailyService = DailySummaryService(
      contextBuilder: store,
      runtime: AppleFoundationModelRuntime(reducer: reducer),
      artifactStore: store,
      sourcePolicy: policyStore
    )
    let liveGenerator: any LiveMeetingGenerating
    do {
      liveGenerator = try LiveMeetingService(
        contextBuilder: store,
        runtime: AppleFoundationModelRuntime(reducer: reducer),
        artifactStore: store,
        sourcePolicy: policyStore
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
      liveMeeting: LiveMeetingModel(generator: liveGenerator),
      sourcePolicyStore: policyStore,
      sourcePolicyPersistence: persistence,
      initialSourcePolicy: initialPolicy
    )
  }

  private static func makeUITest(
    processInfo: ProcessInfo,
    store: any AppContextStore,
    policyStore: DaylineSourcePolicyStore,
    persistence: AppSourcePolicyPersistence,
    initialPolicy: DaylineSourcePolicy
  ) -> AppEnvironment {
    AppEnvironment(
      capture: AppCaptureEnvironment.makeCoordinator(
        processInfo: processInfo,
        eventStore: store
      ),
      dailySummary: DailySummaryModel(generator: EmptyDailySummaryGenerator()),
      liveCapture: AppCaptureEnvironment.makeLiveMeetingCoordinator(
        processInfo: processInfo,
        eventStore: store
      ),
      liveMeeting: LiveMeetingModel(generator: EmptyLiveMeetingGenerator()),
      sourcePolicyStore: policyStore,
      sourcePolicyPersistence: persistence,
      initialSourcePolicy: initialPolicy
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
