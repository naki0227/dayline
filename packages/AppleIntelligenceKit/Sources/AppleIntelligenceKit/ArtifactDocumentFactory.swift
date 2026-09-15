import ContextCoreKit

struct ArtifactGenerationIdentity: Sendable {
  let runtime: String
  let model: String
}

enum ArtifactDocumentFactory {
  static func make(
    request: IntelligenceRequest,
    context: ContextBundleDocument,
    sections: SemanticSections,
    generation: ArtifactGenerationIdentity
  ) throws -> SemanticArtifactDocument {
    let attributes = try SemanticSectionsCodec.attributes(
      for: sections,
      language: request.language
    )
    return SemanticArtifactDocument(
      id: request.artifactID,
      createdAt: request.createdAt,
      dayId: request.dayID,
      sessionId: request.sessionID,
      kind: "summary",
      content: SemanticContentDocument(text: sections.summary, attributes: attributes),
      sourceEventIds: evidenceIDs(in: context, type: .contextEvent),
      sourceArtifactIds: evidenceIDs(in: context, type: .semanticArtifact),
      confidence: nil,
      sensitivity: maximumSensitivity(in: context.items),
      retention: request.retention,
      generation: GenerationProvenanceDocument(
        runtime: generation.runtime,
        model: generation.model,
        promptId: request.promptID,
        promptVersion: request.promptVersion,
        runId: request.runID,
        generatedAt: request.createdAt
      )
    )
  }

  private static func evidenceIDs(
    in context: ContextBundleDocument,
    type: ContextRecordType
  ) -> [String] {
    context.items.compactMap { item in
      item.recordType == type ? item.recordId : nil
    }
  }

  private static func maximumSensitivity(in items: [ContextItemDocument]) -> Sensitivity {
    if items.contains(where: { $0.sensitivity == .restricted }) { return .restricted }
    if items.contains(where: { $0.sensitivity == .sensitive }) { return .sensitive }
    return .standard
  }
}
