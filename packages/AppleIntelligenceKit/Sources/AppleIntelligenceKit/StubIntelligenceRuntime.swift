import ContextCoreKit
import Foundation

public enum StubIntelligenceRuntimeError: Error, Equatable {
  case emptyContext
  case unsupportedSchemaVersion
}

/// Deterministic runtime used to verify the full pipeline without model availability.
public struct StubIntelligenceRuntime: IntelligenceRuntime {
  public init() {}

  public func generate(
    request: IntelligenceRequest,
    context: ContextBundleDocument
  ) async throws -> SemanticArtifactDocument {
    do {
      try context.validateVersion()
    } catch {
      throw StubIntelligenceRuntimeError.unsupportedSchemaVersion
    }
    guard !context.items.isEmpty else {
      throw StubIntelligenceRuntimeError.emptyContext
    }

    let sourceEventIDs = context.items.compactMap { item in
      item.recordType == .contextEvent ? item.recordId : nil
    }
    let sourceArtifactIDs = context.items.compactMap { item in
      item.recordType == .semanticArtifact ? item.recordId : nil
    }
    let summary = context.items
      .map(\.content)
      .joined(separator: "\n")

    return SemanticArtifactDocument(
      id: request.artifactID,
      createdAt: request.createdAt,
      dayId: request.dayID,
      sessionId: request.sessionID,
      kind: "summary",
      content: SemanticContentDocument(
        text: summary,
        attributes: ["language": request.language]
      ),
      sourceEventIds: sourceEventIDs,
      sourceArtifactIds: sourceArtifactIDs,
      confidence: nil,
      sensitivity: maximumSensitivity(in: context.items),
      retention: request.retention,
      generation: GenerationProvenanceDocument(
        runtime: "stub",
        model: "deterministic-stub",
        promptId: request.promptID,
        promptVersion: request.promptVersion,
        runId: request.runID,
        generatedAt: request.createdAt
      )
    )
  }

  private func maximumSensitivity(in items: [ContextItemDocument]) -> Sensitivity {
    if items.contains(where: { $0.sensitivity == .restricted }) {
      return .restricted
    }
    if items.contains(where: { $0.sensitivity == .sensitive }) {
      return .sensitive
    }
    return .standard
  }
}
