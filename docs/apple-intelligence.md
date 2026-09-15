# Apple Intelligence runtime

`AppleIntelligenceKit` is the model-specific boundary. It consumes a versioned
`ContextBundleDocument` and returns a `SemanticArtifactDocument`; it never collects
or persists source data.

## Availability

The package deployment targets remain iOS 18 and macOS 15. Calls to Foundation
Models are guarded at runtime for iOS/macOS 26 or later. The public availability
result distinguishes unsupported OS, ineligible hardware, disabled Apple
Intelligence, and a model that is not ready. Capture and storage callers should
queue generation when the runtime is unavailable rather than stop One Day.

## Context fitting

On iOS/macOS 26.4 or later, the adapter measures the instructions, prompt, and
`@Generable` schema with `SystemLanguageModel.tokenCount`. It reserves output space
from `contextSize`. If input is too large, it applies a 10% safety margin and asks
the injected `ContextReducer` for a smaller bundle.

The production reducer must call `RustContextBridge.shrinkContext`, which delegates
to `shrink_context_bundle`. Rust preserves ranking order and only understands its
platform-neutral `quarter_character_estimate` units. On 26.0 through 26.3, where
the tokenizer API is unavailable, an exceeded-window generation error requests a
deterministic 75% reduction. Retries are bounded.

## Structured output and errors

The Foundation Models implementation uses an internal `@Generable` output with a
summary, highlights, topics, decisions, TODOs, ideas, and questions. The plain summary
remains the SemanticArtifact content text. The complete structured payload is encoded
as deterministic JSON in the versioned `sections_v1` content attribute, so the v1
language-neutral record envelope does not change. Language, prompt ID/version, and
evidence IDs remain traceable in attributes and provenance.

`SemanticSectionsCodec` is the only encoder/decoder for this compatibility payload.
Product and UI layers consume its typed representation and gracefully fall back to
the plain summary when reading an older or malformed artifact.

Errors are mapped to content-free categories such as unavailable, context window,
guardrail, unsupported language, decoding, rate limit, concurrent request, and
refusal. Raw prompts, evidence, model error descriptions, and local paths must not
be logged.
