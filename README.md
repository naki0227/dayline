# Dayline

Dayline is the first product built on a reusable personal Context Engine and an
Apple Intelligence runtime adapter.

```text
Sources -> ContextCore (Rust) -> ContextBundle
                                  |
                                  v
Dayline UI <- AppleIntelligenceKit (Swift)
```

The core architectural rule is that Rust does not know about Apple Intelligence,
Apple Intelligence does not know how context was collected, and the Dayline app
composes both boundaries.

## Repository layout

| Path | Responsibility |
| --- | --- |
| `rust/` | Platform-neutral domain, engine, policy, time, and local store |
| `packages/ContextCoreKit/` | Stable Swift facade over the Rust boundary |
| `packages/ContextCoreFFIKit/` | Generated UniFFI binary adapter and integration tests |
| `packages/AppleIntelligenceKit/` | Apple model runtime adapter |
| `apps/` | Product-specific Apple clients |
| `contracts/` | Versioned cross-language schemas |
| `profiles/` | Product AI profiles and prompt policy |
| `integrations/` | External service adapters |
| `fixtures/` | Deterministic test input |
| `docs/` | Architecture decisions, operations, and work logs |

## Local quality gates

Required tools are Rust, Xcode/Swift, SwiftLint, and Node.js for the advisory
duplication report.

```bash
make ci       # blocking checks
make quality  # advisory cross-cutting checks
make ffi-check # regenerate XCFramework and run the real Swift/Rust bridge tests
```

CI is split by responsibility under `.github/workflows/`. Development is based
on small commits pushed directly to `main`; pull requests are not required.

## Release commands

```bash
make release-dry-run  # signed archive and Apple validation, no upload
make release-upload   # archive, upload, and App Store version association
```

Repository Variables provide non-secret Apple identifiers. GitHub Secrets provide
the certificate, its password, and App Store Connect API credentials. A `v*` tag
runs the upload path; manual dispatch defaults to dry-run.

## Current status

The repository contains strict v1 contracts, validated Rust domain models,
deterministic context assembly, pre-persistence redaction, timezone-aware One Day
validation, a local SQLite store, a reproducible Apple XCFramework, and a tested
Event-to-Artifact vertical slice. The Apple adapter includes availability handling,
typed structured output, real tokenizer measurement, and bounded Rust-backed context
shrinking. The iOS client can start/stop five-minute AAC chunks through an isolated,
interruption-aware capture state machine and remains deployable to iOS 18. On iOS
26+, completed chunks use on-device progressive speech transcription; volatile
hypotheses remain UI-only and finalized segments map to versioned ContextEvents that
are persisted through the real Rust SQLite boundary.
The versioned Daily profile now queries the local store with a timezone-correct
One Day window, sends the assembled ContextBundle through the Apple runtime, persists
the resulting SemanticArtifact, and exposes explicit empty/unavailable states in the
iOS client. Live Meeting has an independent
iOS 26 microphone-to-SpeechAnalyzer stream, session-scoped finalized evidence, and a
profile-driven 30-second meeting-state update loop. Daily and Live artifacts now carry
typed summary, highlight, topic, decision, TODO, idea, and question groups; the iOS UI
shows non-empty groups and their evidence count while preserving legacy summaries.
The app now exposes persisted audio/browser/shell/calendar controls, defaults to audio
only, stops capture when audio is revoked, filters context through both profile and
user policy, and visibly states that processing is local-only. A selected artifact can
be exported to Notion only after Rust policy evaluation and explicit confirmation;
the access token stays in Keychain and raw capture data is not included. macOS Terminal
and Chrome collection is available through an opt-in local agent: completed command
metadata and Chrome visits become strict ContextEvents in the same Rust store, while
stdout, stderr, keystrokes, and collected content stay out of logs.
Product features are tracked in
[`docs/TODO.md`](docs/TODO.md).
macOS collector setup is documented in
[`docs/mac-context.md`](docs/mac-context.md).
