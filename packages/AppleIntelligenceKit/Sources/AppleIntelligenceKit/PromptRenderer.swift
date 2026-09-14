import ContextCoreKit

struct RenderedPrompt: Equatable, Sendable {
  let instructions: String
  let prompt: String
}

enum PromptRenderer {
  static func render(
    request: IntelligenceRequest,
    context: ContextBundleDocument
  ) -> RenderedPrompt {
    let evidence = context.items.map { item in
      "[\(item.citationLabel)] \(item.content)"
    }.joined(separator: "\n")
    return RenderedPrompt(
      instructions: """
        You are Dayline's on-device semantic artifact generator.
        Use only the supplied evidence. Never invent facts.
        Write the result in \(request.language).
        Prompt profile: \(request.promptID) v\(request.promptVersion).
        """,
      prompt: """
        Objective: \(context.task.objective)
        Timezone: \(context.window.timezone)
        Evidence:
        \(evidence)
        """
    )
  }
}
