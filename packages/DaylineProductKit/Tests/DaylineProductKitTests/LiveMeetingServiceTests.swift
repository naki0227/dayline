import AppleIntelligenceKit
import ContextCoreKit
import Foundation
import Testing

@testable import DaylineProductKit

@Test
func liveMeetingBuildsAndPersistsSessionScopedState() async throws {
  let contextBuilder = LiveContextBuilderFake(bundle: liveContextBundle(items: [liveContextItem()]))
  let artifactStore = LiveArtifactStoreFake()
  let service = try LiveMeetingService(
    contextBuilder: contextBuilder,
    runtime: StubIntelligenceRuntime(),
    artifactStore: artifactStore,
    sourcePolicy: DaylineSourcePolicyStore(policy: .allEnabled),
    now: { Date(timeIntervalSince1970: 1_789_320_660) },
    bundleID: { "018f6ea2-8f44-7f00-8000-000000000921" },
    artifactID: { "018f6ea2-8f44-7f00-8000-000000000922" },
    runID: { "018f6ea2-8f44-7f00-8000-000000000923" }
  )
  let sessionID = "018f6ea2-8f44-7f00-8000-000000000920"

  let artifact = try await service.generate(
    sessionID: sessionID,
    startedAt: Date(timeIntervalSince1970: 1_789_320_600),
    timezone: try #require(TimeZone(identifier: "Asia/Tokyo")),
    language: "ja"
  )
  let request = await contextBuilder.request

  #expect(service.updateIntervalSeconds == 30)
  #expect(request?.query.sessionId == sessionID)
  #expect(request?.query.sources.map(\.type) == ["audio"])
  #expect(request?.plan.profile.id == "live-meeting")
  #expect(artifact.sessionId == sessionID)
  #expect(artifact.sourceEventIds == ["018f6ea2-8f44-7f00-8000-000000000901"])
  #expect(await artifactStore.artifacts == [artifact])
}

@Test
func liveMeetingRejectsInvalidAndEmptySessionsBeforeGeneration() async throws {
  let service = try LiveMeetingService(
    contextBuilder: LiveContextBuilderFake(bundle: liveContextBundle(items: [])),
    runtime: StubIntelligenceRuntime(),
    artifactStore: LiveArtifactStoreFake(),
    sourcePolicy: DaylineSourcePolicyStore(policy: .allEnabled),
    now: { Date(timeIntervalSince1970: 1_789_320_660) }
  )
  let timezone = try #require(TimeZone(identifier: "Asia/Tokyo"))

  await #expect(throws: LiveMeetingFailure.invalidSession) {
    try await service.generate(
      sessionID: "invalid",
      startedAt: Date(timeIntervalSince1970: 1_789_320_600),
      timezone: timezone,
      language: "ja"
    )
  }
  await #expect(throws: LiveMeetingFailure.emptyContext) {
    try await service.generate(
      sessionID: "018f6ea2-8f44-7f00-8000-000000000920",
      startedAt: Date(timeIntervalSince1970: 1_789_320_600),
      timezone: timezone,
      language: "ja"
    )
  }
}

@Test
func liveMeetingRejectsGenerationWhenAudioIsDisabled() async throws {
  let contextBuilder = LiveContextBuilderFake(bundle: liveContextBundle(items: [liveContextItem()]))
  let service = try LiveMeetingService(
    contextBuilder: contextBuilder,
    runtime: StubIntelligenceRuntime(),
    artifactStore: LiveArtifactStoreFake(),
    sourcePolicy: DaylineSourcePolicyStore(
      policy: DaylineSourcePolicy(enabledSources: [.calendar])
    ),
    now: { Date(timeIntervalSince1970: 1_789_320_660) }
  )

  await #expect(throws: LiveMeetingFailure.sourceDisabled) {
    try await service.generate(
      sessionID: "018f6ea2-8f44-7f00-8000-000000000920",
      startedAt: Date(timeIntervalSince1970: 1_789_320_600),
      timezone: try #require(TimeZone(identifier: "Asia/Tokyo")),
      language: "ja"
    )
  }
  #expect(await contextBuilder.request == nil)
}

private actor LiveContextBuilderFake: StoredContextBuilding {
  let bundle: ContextBundleDocument
  private(set) var request: StoredContextRequestDocument?

  init(bundle: ContextBundleDocument) {
    self.bundle = bundle
  }

  func buildStoredContext(
    _ request: StoredContextRequestDocument
  ) -> ContextBundleDocument {
    self.request = request
    return bundle
  }
}

private actor LiveArtifactStoreFake: SemanticArtifactPersisting {
  private(set) var artifacts: [SemanticArtifactDocument] = []

  func persist(_ artifact: SemanticArtifactDocument) -> SemanticArtifactDocument {
    artifacts.append(artifact)
    return artifact
  }
}

private func liveContextBundle(items: [ContextItemDocument]) -> ContextBundleDocument {
  ContextBundleDocument(
    id: "018f6ea2-8f44-7f00-8000-000000000924",
    builtAt: "2026-09-14T12:01:00Z",
    task: ContextTaskDocument(id: "live_meeting", objective: "Update meeting state."),
    profile: VersionedIdentifierDocument(id: "live-meeting", version: 1),
    window: ContextWindowDocument(
      start: "2026-09-14T12:00:00Z",
      end: "2026-09-14T12:01:00Z",
      timezone: "Asia/Tokyo"
    ),
    items: items,
    budget: ContextBudgetDocument(maximumUnits: 4_096, includedUnits: UInt64(items.count * 4)),
    processing: ContextProcessingDocument(location: "on_device_only"),
    suggestedTools: [],
    omissions: [],
    assembly: AssemblyProvenanceDocument(
      engine: "context-core",
      engineVersion: "0.1.0",
      policyVersion: 1,
      rankingVersion: 1
    )
  )
}

private func liveContextItem() -> ContextItemDocument {
  ContextItemDocument(
    recordType: .contextEvent,
    recordId: "018f6ea2-8f44-7f00-8000-000000000901",
    occurredAt: "2026-09-14T12:00:02Z",
    content: "meeting transcript",
    contentFormat: .plainText,
    sensitivity: .sensitive,
    relevanceScore: 1,
    estimatedUnits: 4,
    citationLabel: "event:000000000901"
  )
}
