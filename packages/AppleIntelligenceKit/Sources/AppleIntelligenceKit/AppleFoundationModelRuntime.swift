import ContextCoreKit
import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @Generable
  struct GeneratedSemanticArtifact {
    @Guide(description: "A concise evidence-grounded summary")
    var summary: String

    @Guide(description: "The most important evidence-grounded moments")
    var highlights: [String]

    @Guide(description: "Topics discussed or worked on")
    var topics: [String]

    @Guide(description: "Decisions explicitly supported by evidence")
    var decisions: [String]

    @Guide(description: "Concrete TODO items, including an owner only when known")
    var todos: [String]

    @Guide(description: "Ideas or possibilities, kept separate from decisions")
    var ideas: [String]

    @Guide(description: "Open or unanswered questions")
    var questions: [String]
  }
#endif

public struct AppleFoundationModelRuntime: IntelligenceRuntime {
  private let reducer: ContextReducer
  private let maximumAttempts: Int
  private let reservedOutputTokens: Int

  public init(
    reducer: ContextReducer,
    maximumAttempts: Int = 3,
    reservedOutputTokens: Int = 768
  ) {
    self.reducer = reducer
    self.maximumAttempts = max(1, maximumAttempts)
    self.reservedOutputTokens = max(1, reservedOutputTokens)
  }

  public func availability() -> IntelligenceAvailability {
    SystemIntelligenceAvailability.current()
  }

  public func generate(
    request: IntelligenceRequest,
    context: ContextBundleDocument
  ) async throws -> SemanticArtifactDocument {
    do {
      try context.validateVersion()
    } catch {
      throw AppleIntelligenceRuntimeError.invalidContract
    }
    guard !context.items.isEmpty else {
      throw AppleIntelligenceRuntimeError.emptyContext
    }

    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        return try await generateAvailable(request: request, context: context)
      }
    #endif
    throw AppleIntelligenceRuntimeError.unsupportedOperatingSystem
  }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  extension AppleFoundationModelRuntime {
    private func generateAvailable(
      request: IntelligenceRequest,
      context initialContext: ContextBundleDocument
    ) async throws -> SemanticArtifactDocument {
      let model = SystemLanguageModel.default
      guard case .available = model.availability else {
        throw unavailableError(model.availability)
      }

      var context = initialContext
      for attempt in 1...maximumAttempts {
        let rendered = PromptRenderer.render(request: request, context: context)
        #if compiler(>=6.3)
          if #available(iOS 26.4, macOS 26.4, visionOS 26.4, *) {
            let target = try await measuredReductionTarget(
              model: model,
              rendered: rendered,
              currentUnits: context.budget.maximumUnits
            )
            if let target {
              context = try await reduce(context, to: target)
              continue
            }
          }
        #endif

        do {
          return try await generateArtifact(
            model: model,
            rendered: rendered,
            request: request,
            context: context
          )
        } catch let error as LanguageModelSession.GenerationError {
          let target = retryTarget(for: error, attempt: attempt, context: context)
          if let target {
            context = try await reduce(context, to: target)
            continue
          }
          throw mapGenerationError(error)
        } catch let error as AppleIntelligenceRuntimeError {
          throw error
        } catch {
          throw AppleIntelligenceRuntimeError.generationFailed
        }
      }
      throw AppleIntelligenceRuntimeError.contextWindowExceeded
    }

    private func generateArtifact(
      model: SystemLanguageModel,
      rendered: RenderedPrompt,
      request: IntelligenceRequest,
      context: ContextBundleDocument
    ) async throws -> SemanticArtifactDocument {
      let session = LanguageModelSession(
        model: model,
        instructions: rendered.instructions
      )
      let response = try await session.respond(
        to: rendered.prompt,
        generating: GeneratedSemanticArtifact.self
      )
      let sections = SemanticSections(
        summary: response.content.summary,
        highlights: response.content.highlights,
        topics: response.content.topics,
        decisions: response.content.decisions,
        todos: response.content.todos,
        ideas: response.content.ideas,
        questions: response.content.questions
      )
      return try ArtifactDocumentFactory.make(
        request: request,
        context: context,
        sections: sections,
        generation: ArtifactGenerationIdentity(
          runtime: "apple-foundation-models",
          model: "system-language-model"
        )
      )
    }

    private func retryTarget(
      for error: LanguageModelSession.GenerationError,
      attempt: Int,
      context: ContextBundleDocument
    ) -> UInt64? {
      guard case .exceededContextWindowSize = error, attempt < maximumAttempts else {
        return nil
      }
      return ContextWindowPlanner.fallbackTarget(currentUnits: context.budget.maximumUnits)
    }

    #if compiler(>=6.3)
      @available(iOS 26.4, macOS 26.4, visionOS 26.4, *)
      private func measuredReductionTarget(
        model: SystemLanguageModel,
        rendered: RenderedPrompt,
        currentUnits: UInt64
      ) async throws -> UInt64? {
        do {
          let instructions = Instructions(rendered.instructions)
          let promptTokens = try await model.tokenCount(for: rendered.prompt)
          let instructionTokens = try await model.tokenCount(for: instructions)
          let schemaTokens = try await model.tokenCount(
            for: GeneratedSemanticArtifact.generationSchema)
          let measured = promptTokens + instructionTokens + schemaTokens
          let allowed = model.contextSize - reservedOutputTokens
          return ContextWindowPlanner.measuredTarget(
            currentUnits: currentUnits,
            measuredTokens: measured,
            allowedTokens: allowed
          )
        } catch {
          throw AppleIntelligenceRuntimeError.generationFailed
        }
      }
    #endif

    private func reduce(
      _ context: ContextBundleDocument,
      to maximumUnits: UInt64
    ) async throws -> ContextBundleDocument {
      do {
        let reduced = try await reducer.reduce(context, maximumUnits: maximumUnits)
        guard !reduced.items.isEmpty else {
          throw AppleIntelligenceRuntimeError.contextWindowExceeded
        }
        return reduced
      } catch let error as AppleIntelligenceRuntimeError {
        throw error
      } catch {
        throw AppleIntelligenceRuntimeError.reductionFailed
      }
    }

    private func unavailableError(
      _ availability: SystemLanguageModel.Availability
    ) -> AppleIntelligenceRuntimeError {
      switch availability {
      case .available:
        return .generationFailed
      case .unavailable(.deviceNotEligible):
        return .unavailable(.deviceNotEligible)
      case .unavailable(.appleIntelligenceNotEnabled):
        return .unavailable(.appleIntelligenceNotEnabled)
      case .unavailable(.modelNotReady):
        return .unavailable(.modelNotReady)
      case .unavailable:
        return .unavailable(.modelNotReady)
      }
    }

    private func mapGenerationError(
      _ error: LanguageModelSession.GenerationError
    ) -> AppleIntelligenceRuntimeError {
      switch error {
      case .exceededContextWindowSize: .contextWindowExceeded
      case .assetsUnavailable: .assetsUnavailable
      case .guardrailViolation: .guardrailViolation
      case .unsupportedGuide: .generationFailed
      case .unsupportedLanguageOrLocale: .unsupportedLanguage
      case .decodingFailure: .decodingFailure
      case .rateLimited: .rateLimited
      case .concurrentRequests: .concurrentRequest
      case .refusal: .refused
      @unknown default: .generationFailed
      }
    }
  }
#endif
