import AppleIntelligenceKit
import ContextCoreKit
import Foundation

public enum DailySummaryFailure: Error, Equatable, Sendable {
  case invalidDay
  case invalidProfile
  case contextUnavailable
  case emptyContext
  case generationUnavailable
  case persistenceFailed
}

public protocol DailySummaryGenerating: Sendable {
  func generate(
    for date: Date,
    timezone: TimeZone,
    language: String
  ) async throws -> SemanticArtifactDocument
}

public struct DailySummaryService: Sendable {
  private let contextBuilder: any StoredContextBuilding
  private let runtime: any IntelligenceRuntime
  private let artifactStore: any SemanticArtifactPersisting
  private let profiles: DaylineProfileCatalog
  private let now: @Sendable () -> Date
  private let bundleID: @Sendable () -> String
  private let artifactID: @Sendable () -> String
  private let runID: @Sendable () -> String

  public init(
    contextBuilder: any StoredContextBuilding,
    runtime: any IntelligenceRuntime,
    artifactStore: any SemanticArtifactPersisting,
    profiles: DaylineProfileCatalog = DaylineProfileCatalog(),
    now: @escaping @Sendable () -> Date = Date.init,
    bundleID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
    artifactID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
    runID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
  ) {
    self.contextBuilder = contextBuilder
    self.runtime = runtime
    self.artifactStore = artifactStore
    self.profiles = profiles
    self.now = now
    self.bundleID = bundleID
    self.artifactID = artifactID
    self.runID = runID
  }

  public func generate(
    for date: Date,
    timezone: TimeZone,
    language: String
  ) async throws -> SemanticArtifactDocument {
    let profile: DaylineAIProfile
    do {
      profile = try profiles.load(.dailySummary)
    } catch {
      throw DailySummaryFailure.invalidProfile
    }
    let timestamp = now()
    let window = try dayWindow(containing: date, timezone: timezone)
    let context: ContextBundleDocument
    do {
      context = try await contextBuilder.buildStoredContext(
        contextRequest(profile: profile, window: window, builtAt: timestamp)
      )
    } catch {
      throw DailySummaryFailure.contextUnavailable
    }
    guard !context.items.isEmpty else { throw DailySummaryFailure.emptyContext }

    let artifact: SemanticArtifactDocument
    do {
      artifact = try await runtime.generate(
        request: IntelligenceRequest(
          artifactID: artifactID(),
          runID: runID(),
          createdAt: iso8601(timestamp),
          dayID: window.dayID,
          sessionID: nil,
          promptID: profile.id.rawValue,
          promptVersion: profile.version,
          language: language,
          retention: RetentionDocument(type: "days", days: 30)
        ),
        context: context
      )
    } catch {
      throw DailySummaryFailure.generationUnavailable
    }
    do {
      return try await artifactStore.persist(artifact)
    } catch {
      throw DailySummaryFailure.persistenceFailed
    }
  }

  private func contextRequest(
    profile: DaylineAIProfile,
    window: OneDayWindow,
    builtAt: Date
  ) -> StoredContextRequestDocument {
    StoredContextRequestDocument(
      dayId: window.dayID,
      plan: StoredContextPlanDocument(
        id: bundleID(),
        builtAt: iso8601(builtAt),
        task: ContextTaskDocument(
          id: "daily_summary",
          objective: "Create a structured daily summary with decisions and next actions."
        ),
        profile: VersionedIdentifierDocument(id: profile.id.rawValue, version: profile.version),
        timezone: window.dayID.timezone,
        processing: ContextProcessingDocument(location: "on_device_only"),
        suggestedTools: suggestedTools(profile),
        assembly: AssemblyProvenanceDocument(
          engine: "context-core",
          engineVersion: "0.1.0",
          policyVersion: 1,
          rankingVersion: 1
        )
      ),
      query: StoredContextQueryDocument(
        start: iso8601(window.start),
        end: iso8601(window.end),
        sources: [],
        sessionId: nil,
        projectHint: nil,
        maximumSensitivity: .sensitive,
        maximumContextUnits: 4_096
      )
    )
  }

  private func suggestedTools(_ profile: DaylineAIProfile) -> [SuggestedToolDocument] {
    let reads = profile.tools.read.map {
      SuggestedToolDocument(name: $0, access: "read", reason: "Profile-approved context")
    }
    let writes = profile.tools.write.map {
      SuggestedToolDocument(name: $0, access: "write", reason: "Explicit output destination")
    }
    return reads + writes
  }
}

extension DailySummaryService: DailySummaryGenerating {}

private struct OneDayWindow: Sendable {
  let dayID: DayIDDocument
  let start: Date
  let end: Date
}

private func dayWindow(containing date: Date, timezone: TimeZone) throws -> OneDayWindow {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = timezone
  let start = calendar.startOfDay(for: date)
  guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
    throw DailySummaryFailure.invalidDay
  }
  let formatter = DateFormatter()
  formatter.calendar = calendar
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = timezone
  formatter.dateFormat = "yyyy-MM-dd"
  return OneDayWindow(
    dayID: DayIDDocument(localDate: formatter.string(from: start), timezone: timezone.identifier),
    start: start,
    end: end
  )
}

private func iso8601(_ date: Date) -> String {
  ISO8601DateFormatter().string(from: date)
}
