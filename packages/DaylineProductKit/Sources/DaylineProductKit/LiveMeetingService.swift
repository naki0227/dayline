import AppleIntelligenceKit
import ContextCoreKit
import Foundation

public enum LiveMeetingFailure: Error, Equatable, Sendable {
  case invalidProfile
  case invalidSession
  case contextUnavailable
  case emptyContext
  case generationUnavailable
  case persistenceFailed
}

public protocol LiveMeetingGenerating: Sendable {
  var updateIntervalSeconds: UInt16 { get }

  func generate(
    sessionID: String,
    startedAt: Date,
    timezone: TimeZone,
    language: String
  ) async throws -> SemanticArtifactDocument
}

public struct LiveMeetingService: LiveMeetingGenerating, Sendable {
  public let updateIntervalSeconds: UInt16

  private let contextBuilder: any StoredContextBuilding
  private let runtime: any IntelligenceRuntime
  private let artifactStore: any SemanticArtifactPersisting
  private let profile: DaylineAIProfile
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
  ) throws {
    let profile: DaylineAIProfile
    do {
      profile = try profiles.load(.liveMeeting)
    } catch {
      throw LiveMeetingFailure.invalidProfile
    }
    guard let interval = profile.update.minimumIntervalSeconds else {
      throw LiveMeetingFailure.invalidProfile
    }
    self.contextBuilder = contextBuilder
    self.runtime = runtime
    self.artifactStore = artifactStore
    self.profile = profile
    updateIntervalSeconds = interval
    self.now = now
    self.bundleID = bundleID
    self.artifactID = artifactID
    self.runID = runID
  }

  public func generate(
    sessionID: String,
    startedAt: Date,
    timezone: TimeZone,
    language: String
  ) async throws -> SemanticArtifactDocument {
    guard UUID(uuidString: sessionID) != nil else {
      throw LiveMeetingFailure.invalidSession
    }
    let timestamp = now()
    guard startedAt < timestamp else { throw LiveMeetingFailure.invalidSession }
    let dayID = dayID(for: startedAt, timezone: timezone)
    let context: ContextBundleDocument
    do {
      context = try await contextBuilder.buildStoredContext(
        contextRequest(
          sessionID: sessionID,
          dayID: dayID,
          startedAt: startedAt,
          builtAt: timestamp
        )
      )
    } catch {
      throw LiveMeetingFailure.contextUnavailable
    }
    guard !context.items.isEmpty else { throw LiveMeetingFailure.emptyContext }

    let artifact: SemanticArtifactDocument
    do {
      artifact = try await runtime.generate(
        request: IntelligenceRequest(
          artifactID: artifactID(),
          runID: runID(),
          createdAt: iso8601(timestamp),
          dayID: dayID,
          sessionID: sessionID,
          promptID: profile.id.rawValue,
          promptVersion: profile.version,
          language: language,
          retention: RetentionDocument(type: "days", days: 30)
        ),
        context: context
      )
    } catch {
      throw LiveMeetingFailure.generationUnavailable
    }
    do {
      return try await artifactStore.persist(artifact)
    } catch {
      throw LiveMeetingFailure.persistenceFailed
    }
  }

  private func contextRequest(
    sessionID: String,
    dayID: DayIDDocument,
    startedAt: Date,
    builtAt: Date
  ) -> StoredContextRequestDocument {
    StoredContextRequestDocument(
      dayId: dayID,
      plan: StoredContextPlanDocument(
        id: bundleID(),
        builtAt: iso8601(builtAt),
        task: ContextTaskDocument(
          id: "live_meeting",
          objective: "Update the meeting topic, decisions, actions, and open questions."
        ),
        profile: VersionedIdentifierDocument(id: profile.id.rawValue, version: profile.version),
        timezone: dayID.timezone,
        processing: ContextProcessingDocument(location: "on_device_only"),
        suggestedTools: profile.tools.read.map {
          SuggestedToolDocument(
            name: $0,
            access: "read",
            reason: "Profile-approved meeting context"
          )
        },
        assembly: AssemblyProvenanceDocument(
          engine: "context-core",
          engineVersion: "0.1.0",
          policyVersion: 1,
          rankingVersion: 1
        )
      ),
      query: StoredContextQueryDocument(
        start: iso8601(startedAt),
        end: iso8601(builtAt),
        sources: [ContextSourceDocument(type: "audio")],
        sessionId: sessionID,
        projectHint: nil,
        maximumSensitivity: .sensitive,
        maximumContextUnits: 4_096
      )
    )
  }
}

private func dayID(for date: Date, timezone: TimeZone) -> DayIDDocument {
  let formatter = DateFormatter()
  formatter.calendar = Calendar(identifier: .gregorian)
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = timezone
  formatter.dateFormat = "yyyy-MM-dd"
  return DayIDDocument(localDate: formatter.string(from: date), timezone: timezone.identifier)
}

private func iso8601(_ date: Date) -> String {
  ISO8601DateFormatter().string(from: date)
}
