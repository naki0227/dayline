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

    let summary = context.items
      .map(\.content)
      .joined(separator: "\n")

    return try ArtifactDocumentFactory.make(
      request: request,
      context: context,
      sections: SemanticSections(
        summary: summary,
        highlights: Array(context.items.prefix(3).map(\.content)),
        topics: [],
        decisions: [],
        todos: [],
        ideas: [],
        questions: []
      ),
      generation: ArtifactGenerationIdentity(
        runtime: "stub",
        model: "deterministic-stub"
      )
    )
  }
}
