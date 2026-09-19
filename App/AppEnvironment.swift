import AppleIntelligenceKit
import ContextCaptureKit
import ContextCoreFFIKit
import ContextCoreKit
import DaylineProductKit
import Foundation
import NotionKit

@MainActor
struct AppEnvironment {
  let capture: CaptureCoordinator
  let dailySummary: DailySummaryModel
  let liveCapture: LiveMeetingCoordinator
  let liveMeeting: LiveMeetingModel
  let sourcePolicyStore: DaylineSourcePolicyStore
  let sourcePolicyPersistence: AppSourcePolicyPersistence
  let initialSourcePolicy: DaylineSourcePolicy
  let notionExport: NotionExportModel
  let notionCredentials: any NotionCredentialStoring
  let notionConnection: NotionConnectionModel
  let notionConfiguration: AppNotionConfiguration

  static func make(processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
    let store = AppCaptureEnvironment.makeContextStore()
    let persistence = AppSourcePolicyPersistence()
    let isUITesting = processInfo.arguments.contains("--ui-testing")
    let initialPolicy = isUITesting ? DaylineSourcePolicy.localDefault : persistence.load()
    let sourcePolicyStore = DaylineSourcePolicyStore(policy: initialPolicy)
    let notionCredentials: any NotionCredentialStoring =
      isUITesting
      ? InMemoryNotionCredentialStore()
      : KeychainNotionCredentialStore()
    let notionWriter: any NotionOutputWriting =
      isUITesting
      ? DeterministicNotionWriter()
      : NotionPageWriter(credentials: notionCredentials)
    let notionExport = NotionExportModel(
      service: NotionExportService(policy: AppActionPolicyAdapter(), writer: notionWriter)
    )
    let notionConnection = makeNotionConnection(
      processInfo: processInfo,
      credentials: notionCredentials
    )
    let shared = AppSharedComposition(
      store: store,
      policyStore: sourcePolicyStore,
      policyPersistence: persistence,
      initialPolicy: initialPolicy,
      notionExport: notionExport,
      notionCredentials: notionCredentials,
      notionConnection: notionConnection,
      notionConfiguration: AppNotionConfiguration()
    )
    if isUITesting {
      return makeUITest(processInfo: processInfo, shared: shared)
    }
    return makeProduction(processInfo: processInfo, shared: shared)
  }

  private static func makeProduction(
    processInfo: ProcessInfo,
    shared: AppSharedComposition
  ) -> AppEnvironment {
    let bridge = RustContextBridge()
    let reducer = ContextReducer { context, maximumUnits in
      try bridge.shrinkContext(context, maximumUnits: maximumUnits)
    }
    let dailyService = DailySummaryService(
      contextBuilder: shared.store,
      runtime: AppleFoundationModelRuntime(reducer: reducer),
      artifactStore: shared.store,
      sourcePolicy: shared.policyStore
    )
    let liveGenerator: any LiveMeetingGenerating
    do {
      liveGenerator = try LiveMeetingService(
        contextBuilder: shared.store,
        runtime: AppleFoundationModelRuntime(reducer: reducer),
        artifactStore: shared.store,
        sourcePolicy: shared.policyStore
      )
    } catch {
      liveGenerator = UnavailableLiveMeetingGenerator()
    }
    return AppEnvironment(
      capture: AppCaptureEnvironment.makeCoordinator(
        processInfo: processInfo,
        eventStore: shared.store
      ),
      dailySummary: DailySummaryModel(generator: dailyService),
      liveCapture: AppCaptureEnvironment.makeLiveMeetingCoordinator(
        processInfo: processInfo,
        eventStore: shared.store
      ),
      liveMeeting: LiveMeetingModel(generator: liveGenerator),
      sourcePolicyStore: shared.policyStore,
      sourcePolicyPersistence: shared.policyPersistence,
      initialSourcePolicy: shared.initialPolicy,
      notionExport: shared.notionExport,
      notionCredentials: shared.notionCredentials,
      notionConnection: shared.notionConnection,
      notionConfiguration: shared.notionConfiguration
    )
  }

  private static func makeUITest(
    processInfo: ProcessInfo,
    shared: AppSharedComposition
  ) -> AppEnvironment {
    AppEnvironment(
      capture: AppCaptureEnvironment.makeCoordinator(
        processInfo: processInfo,
        eventStore: shared.store
      ),
      dailySummary: DailySummaryModel(generator: uiTestDailyGenerator(processInfo: processInfo)),
      liveCapture: AppCaptureEnvironment.makeLiveMeetingCoordinator(
        processInfo: processInfo,
        eventStore: shared.store
      ),
      liveMeeting: LiveMeetingModel(generator: EmptyLiveMeetingGenerator()),
      sourcePolicyStore: shared.policyStore,
      sourcePolicyPersistence: shared.policyPersistence,
      initialSourcePolicy: shared.initialPolicy,
      notionExport: shared.notionExport,
      notionCredentials: shared.notionCredentials,
      notionConnection: shared.notionConnection,
      notionConfiguration: shared.notionConfiguration
    )
  }

  private static func uiTestDailyGenerator(
    processInfo: ProcessInfo
  ) -> any DailySummaryGenerating {
    processInfo.arguments.contains("--ui-testing-notion")
      ? ReadyDailySummaryGenerator()
      : EmptyDailySummaryGenerator()
  }

}

@MainActor
private struct AppSharedComposition {
  let store: any AppContextStore
  let policyStore: DaylineSourcePolicyStore
  let policyPersistence: AppSourcePolicyPersistence
  let initialPolicy: DaylineSourcePolicy
  let notionExport: NotionExportModel
  let notionCredentials: any NotionCredentialStoring
  let notionConnection: NotionConnectionModel
  let notionConfiguration: AppNotionConfiguration
}

private struct DeterministicNotionWriter: NotionOutputWriting {
  func write(_: ActionProposalDocument) -> ExternalOutputReceipt {
    ExternalOutputReceipt(remoteID: "ui-test-notion-page", remoteURL: nil)
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

private struct ReadyDailySummaryGenerator: DailySummaryGenerating {
  func generate(
    for _: Date,
    timezone _: TimeZone,
    language _: String
  ) -> SemanticArtifactDocument {
    SemanticArtifactDocument(
      id: "018f6ea2-8f44-7f00-8000-000000000961",
      createdAt: "2026-09-15T01:00:00Z",
      dayId: DayIDDocument(localDate: "2026-09-15", timezone: "Asia/Tokyo"),
      sessionId: nil,
      kind: "summary",
      content: SemanticContentDocument(text: "UI test summary", attributes: ["language": "en"]),
      sourceEventIds: ["018f6ea2-8f44-7f00-8000-000000000962"],
      sourceArtifactIds: [],
      confidence: nil,
      sensitivity: .sensitive,
      retention: RetentionDocument(type: "days", days: 30),
      generation: GenerationProvenanceDocument(
        runtime: "deterministic-test",
        model: "deterministic-test",
        promptId: "daily-summary",
        promptVersion: 1,
        runId: "018f6ea2-8f44-7f00-8000-000000000963",
        generatedAt: "2026-09-15T01:00:00Z"
      )
    )
  }
}
