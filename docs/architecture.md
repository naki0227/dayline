# Architecture

## System boundary

```text
Apple clients
  Dayline iOS / widgets / macOS collector
             |
             v
ContextCoreKit (Swift facade)
             |
             v
ContextCoreFFIKit (generated UniFFI adapter)
             |
             v
Context Engine (Rust)
  domain -> normalization -> policy -> query -> ranking -> assembly
       time validation -> redaction -> local store
             |
             v
ContextBundle
             |
             v
AppleIntelligenceKit
  availability -> prompt selection -> token measurement -> structured output
```

## Dependency rules

1. `context-domain` is platform neutral and cannot import database, HTTP, FFI, or
   Apple frameworks.
2. Context Engine components depend inward on domain contracts.
3. `ContextCoreKit` exposes stable Swift DTOs and cannot import UI, capture,
   persistence, or model-runtime frameworks.
4. `ContextCoreFFIKit` owns generated bindings and binary linkage. Its public
   adapter maps failures to content-free categories.
5. `AppleIntelligenceKit` may depend on `ContextCoreKit`; the reverse dependency
   is forbidden.
6. Apps compose packages and platform adapters. Business policy does not belong
   in SwiftUI views.
7. Integrations execute an `ActionProposal` only after deterministic permission
   evaluation. AI output never bypasses policy.

These rules are checked by `scripts/check-architecture.sh` and the Architecture
workflow. Package and Cargo manifests provide additional compile-time boundaries.

## Core records

- `ContextEvent` is an observed fact with provenance and sensitivity metadata.
- `SemanticArtifact` is model-derived meaning and references source Events and/or
  earlier Artifacts without cycles.
- `ContextBundle` is the versioned model-runtime input selected for a task and
  an abstract estimate budget. Model-specific token limits are not Rust concepts.
- `ActionProposal` is an unexecuted external side effect subject to policy.

Raw observations and generated meaning must never share the same record type.

## Storage and synchronization

- Rust-owned SQLite is the device-local source of detailed context.
- The store validates an IANA timezone-derived local day and redacts secrets before
  every write. Records are immutable; duplicate IDs are rejected.
- Artifact evidence uses normalized foreign-key tables and must form an acyclic
  provenance graph.
- Audio, raw transcripts, shell details, and browser details stay local by
  default.
- CloudKit carries explicitly allowed lightweight events, semantic artifacts,
  summaries, settings, policies, and connector configuration.
- A SQLite database file is never synchronized directly through iCloud.

Migration and rollback details are in `docs/storage.md`.

## Security and privacy

- Terminal secrets are redacted before persistence.
- Standard output, standard error, and individual keystrokes are not collected.
- External writes default to confirmation; destructive actions default to deny.
- Credentials are stored in Keychain locally and GitHub Secrets in CD.
- Logs must contain identifiers needed for diagnosis but no raw secrets or
  unnecessary personal content.
- `DaylineSourcePolicy` is the shared user allowlist. Product services intersect it
  with profile declarations before querying Rust. An empty intersection fails closed;
  it is never encoded as Rust's intentionally broad empty-source filter.
- The app persists only source identifiers in UserDefaults. Disabling audio stops
  active Daily/Live capture before the new policy is published. Detailed context and
  connector credentials are not part of this settings record.

## Test strategy

- Rust unit tests cover domain invariants, normalization, day boundaries,
  redaction, policy, ranking, and shrinking.
- Swift unit tests cover facade conversion, runtime availability, structured
  output mapping, prompt selection, and error mapping.
- Adapter integration tests cover SQLite, CloudKit, audio, speech, and FFI at
  their boundaries.
- Fixture/golden tests cover deterministic multi-hour context assembly.
- Architecture tests block invalid dependency directions.
- Duplication reporting is advisory so it informs refactoring without blocking
  delivery on incidental similarity.

## Apple model runtime

- The package remains deployable to iOS 18/macOS 15. Foundation Models symbols are
  isolated behind iOS/macOS 26 availability checks.
- On 26.4+, Swift measures instructions, prompt, and generated schema with the
  system model tokenizer. Rust never receives model token semantics.
- If the measured input does not fit, Swift converts the ratio to a smaller
  abstract unit budget and calls an injected `ContextReducer`. The production
  reducer delegates to the Rust `shrink_context_bundle` FFI function.
- On earlier 26.x versions, an exceeded-context error triggers a deterministic
  75% abstract-budget retry. Retries are bounded and empty reductions fail closed.
- Model availability and generation failures are content-free typed errors, so
  callers can queue work without logging private context.

## Capture runtime

- `ContextCaptureKit` owns capture state and AVFAudio adapters, but not UI, model
  generation, FFI, or persistence.
- Daily capture and audio-source state are independent. An interruption changes
  audio from recording to interrupted while Daily remains running.
- Passive audio is AAC-LC, mono, 16 kHz, 32 kbps and rotates into a new local file
  every five minutes. Files live below Application Support/audio/One-Day-date.
- The app targets iOS 18. Foundation Models availability never gates recording.
- The UI test launch argument injects an in-memory deterministic recorder and is
  used only by the test composition root; production still uses AVAudioRecorder.
- `SpeechTranscribing` isolates iOS 26 SpeechAnalyzer APIs. Missing authorization,
  locale support, assets, or valid audio produces content-free typed failures and
  never stops Daily capture.
- Volatile speech hypotheses are presentation state only. Final segments are
  deduplicated before `TranscriptEventMapper` emits versioned ContextEvent DTOs;
  persistence is composed through a Core-owned protocol.
- The app composition root injects ContextCoreFFIKit's typed Rust store. CaptureKit
  imports neither generated FFI nor SQLite, while every app build/archive must link a
  freshly generated XCFramework.

## Product runtime

- `DaylineProductKit` owns versioned Daily and Live Meeting profiles, product use
  cases, and presentation state. It does not own SQLite, generated FFI, or SwiftUI.
- `DailySummaryService` calculates a half-open One Day interval in the selected IANA
  timezone, asks the Core-owned store port for a ContextBundle, invokes an injected
  `IntelligenceRuntime`, and persists the resulting SemanticArtifact through a
  separate Core-owned port.
- The app composition root provides one `RustContextStore` to capture, context
  assembly, and artifact persistence. This keeps storage identity consistent without
  allowing ProductKit or CaptureKit to know the database path.
- Empty context stops before model invocation. Store, runtime, and persistence
  failures cross the product boundary as finite content-free states.
- UI tests inject a deterministic empty-day generator and never invoke the system
  model. Actual Apple Intelligence generation remains an on-device verification item.
- Live capture uses a separate `LiveSpeechStreaming` port and `AVAudioEngine` adapter.
  The app makes Daily recording and Live Meeting mutually exclusive so two owners
  never compete for the microphone/audio session.
- Final Live segments receive a meeting session ID before persistence. ProductKit
  queries only that session and uses the profile's 30-second interval for incremental
  generation; volatile speech never reaches context assembly.
- AppleIntelligenceKit owns the typed generated schema and encodes its seven semantic
  groups into the `sections_v1` content attribute without changing the v1 artifact
  envelope. DaylineProductKit owns decoding and presentation DTOs; SwiftUI only maps
  those DTOs to reusable Daily and Live sections. Legacy artifacts remain readable.
- A single actor-backed source-policy snapshot is injected into Daily and Live
  services. SwiftUI requests changes through the app composition model and does not
  decide query authorization itself.
