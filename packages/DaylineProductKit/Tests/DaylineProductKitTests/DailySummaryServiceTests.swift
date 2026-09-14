import AppleIntelligenceKit
import ContextCoreKit
import Foundation
import Testing

@testable import DaylineProductKit

private actor ContextBuilderFake: StoredContextBuilding {
  let bundle: ContextBundleDocument
  private(set) var request: StoredContextRequestDocument?

  init(bundle: ContextBundleDocument) {
    self.bundle = bundle
  }

  func buildStoredContext(
    _ request: StoredContextRequestDocument
  ) async throws -> ContextBundleDocument {
    self.request = request
    return bundle
  }
}

private actor ArtifactStoreFake: SemanticArtifactPersisting {
  private(set) var artifacts: [SemanticArtifactDocument] = []

  func persist(
    _ artifact: SemanticArtifactDocument
  ) async throws -> SemanticArtifactDocument {
    artifacts.append(artifact)
    return artifact
  }
}

@Test
func generatesAndPersistsADailySummaryFromOneDayContext() async throws {
  let contextBuilder = ContextBuilderFake(bundle: contextBundle(items: [contextItem()]))
  let artifactStore = ArtifactStoreFake()
  let service = DailySummaryService(
    contextBuilder: contextBuilder,
    runtime: StubIntelligenceRuntime(),
    artifactStore: artifactStore,
    now: { Date(timeIntervalSince1970: 1_789_344_000) },
    bundleID: { "018f6ea2-8f44-7f00-8000-000000000911" },
    artifactID: { "018f6ea2-8f44-7f00-8000-000000000912" },
    runID: { "018f6ea2-8f44-7f00-8000-000000000913" }
  )

  let artifact = try await service.generate(
    for: Date(timeIntervalSince1970: 1_789_344_000),
    timezone: try #require(TimeZone(identifier: "Asia/Tokyo")),
    language: "ja"
  )
  let request = await contextBuilder.request
  let persisted = await artifactStore.artifacts

  #expect(request?.dayId.localDate == "2026-09-14")
  #expect(request?.plan.profile.id == "daily-summary")
  #expect(request?.plan.suggestedTools.map(\.name) == ["calendar", "notion"])
  #expect(artifact.sourceEventIds == ["018f6ea2-8f44-7f00-8000-000000000901"])
  #expect(artifact.generation.promptId == "daily-summary")
  #expect(persisted == [artifact])
}

@Test
func doesNotInvokeTheModelForAnEmptyDay() async throws {
  let service = DailySummaryService(
    contextBuilder: ContextBuilderFake(bundle: contextBundle(items: [])),
    runtime: StubIntelligenceRuntime(),
    artifactStore: ArtifactStoreFake()
  )
  let timezone = try #require(TimeZone(identifier: "Asia/Tokyo"))

  await #expect(throws: DailySummaryFailure.emptyContext) {
    try await service.generate(for: Date(), timezone: timezone, language: "ja")
  }
}

private func contextBundle(items: [ContextItemDocument]) -> ContextBundleDocument {
  ContextBundleDocument(
    id: "018f6ea2-8f44-7f00-8000-000000000910",
    builtAt: "2026-09-14T12:00:00Z",
    task: ContextTaskDocument(id: "daily_summary", objective: "Summarize the day."),
    profile: VersionedIdentifierDocument(id: "daily-summary", version: 1),
    window: ContextWindowDocument(
      start: "2026-09-13T15:00:00Z",
      end: "2026-09-14T15:00:00Z",
      timezone: "Asia/Tokyo"
    ),
    items: items,
    budget: ContextBudgetDocument(maximumUnits: 4_096, includedUnits: 4),
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

private func contextItem() -> ContextItemDocument {
  ContextItemDocument(
    recordType: .contextEvent,
    recordId: "018f6ea2-8f44-7f00-8000-000000000901",
    occurredAt: "2026-09-14T01:00:00Z",
    content: "meeting notes",
    contentFormat: .plainText,
    sensitivity: .sensitive,
    relevanceScore: 1,
    estimatedUnits: 4,
    citationLabel: "event:000000000901"
  )
}
