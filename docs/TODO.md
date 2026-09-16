# Dayline Todo

## In progress

- [ ] Run the Phase 1 acceptance audit and close GitHub Issue #11 after all pushed
      responsibility workflows pass.

## Not started

- [ ] Add Calendar read/write adapters behind source allowlisting and ActionProposal policy.
- [ ] Add Live Activity, App Intent, and Control Center capture controls.
- [ ] Add CloudKit synchronization for explicitly allowed lightweight records;
      never synchronize the SQLite file.
- [ ] Add Swift dependency auditing when third-party Swift dependencies are introduced.

## Completed

- [x] Create the public GitHub repository and split CI by responsibility.
- [x] Add advisory code-duplication reporting and architecture checks.
- [x] Establish ContextCoreKit and AppleIntelligenceKit package boundaries.
- [x] Add the minimal Dayline iOS target and unsigned CI build.
- [x] Reproduce the `useful_map` Makefile-driven tag App Store CD shape.
- [x] Add secret scanning plus Rust and Python dependency audits.
- [x] Define all four strict v1 contracts with positive and negative fixtures.
- [x] Implement validated Rust ContextEvent, SemanticArtifact, ContextBundle, and
      ActionProposal domain models.
- [x] Enforce Event kind/payload compatibility and event/artifact provenance.
- [x] Add deterministic normalization, redaction, query, ranking, policy, and
      ContextBundle assembly crates with tests.
- [x] Keep model-specific token measurement out of Rust by using explicit abstract
      quarter-character estimate units.
- [x] Validate One Day against an IANA timezone, including date-boundary tests.
- [x] Add a Rust-owned SQLite store with pre-persistence redaction, immutable IDs,
      evidence foreign keys, cycle checks, migrations, and rollback documentation.
- [x] Select pinned UniFFI with a narrow versioned JSON boundary and record ADR 0005.
- [x] Generate iOS device, universal iOS Simulator, and universal macOS XCFramework
      slices through `make ffi-xcframework`.
- [x] Add typed Swift contract DTOs and a content-safe Rust bridge adapter.
- [x] Complete and test the vertical slice:
      `ContextEvent -> Rust ContextBundle -> ContextCoreKit -> AppleIntelligenceKit
      stub -> SemanticArtifact -> local SQLite persistence`.
- [x] Close architecture guardrail issue #1 after local `make ci` and all nine
      responsibility-specific GitHub Actions passed.
- [x] Add Foundation Models availability mapping, `@Generable` output, actual
      token measurement on 26.4+, typed errors, and deterministic Rust shrink retry.
- [x] Add ContextCaptureKit with iPhone AAC mono long recording, five-minute chunk
      rotation, interruption recovery, and independent Daily/Audio state.
- [x] Add the Dayline start/stop screen and a permission-free deterministic UI
      test harness, and run it in the Apple App workflow.
- [x] Keep the app target on iOS 18 so capture/storage work without Apple
      Intelligence; model features remain availability-gated.
- [x] Add iOS 26 progressive on-device speech transcription behind a protocol,
      keep volatile hypotheses separate, and map finalized segments to v1
      ContextEvents with deterministic tests.
- [x] Link the real Rust XCFramework into app builds and persist finalized transcript
      ContextEvents through a typed Core protocol without exposing FFI or SQLite to
      ContextCaptureKit.
- [x] Add versioned Daily Summary and Live Meeting profiles as validated package
      resources.
- [x] Build the Daily Summary vertical slice from a timezone-correct One Day Rust
      store query through Apple runtime generation to SemanticArtifact persistence.
- [x] Add Daily Summary presentation states and deterministic UI coverage without
      invoking Apple Intelligence in CI.
- [x] Add an iOS 26 AVAudioEngine-to-SpeechAnalyzer Live stream with shared asset
      preparation and content-free failure cleanup.
- [x] Persist only finalized Live transcript evidence with a meeting session ID;
      volatile results remain presentation-only.
- [x] Add profile-driven 30-second Live Meeting context updates, artifact persistence,
      visible Live state, exclusive audio ownership, and deterministic UI coverage.
- [x] Expand Apple structured output into summary, highlights, topics, decisions,
      TODOs, ideas, and questions while preserving source provenance.
- [x] Decode structured artifacts in DaylineProductKit and render reusable, non-empty
      Daily and Live sections with an evidence count in the iOS app.
- [x] Add persisted, typed audio/browser/shell/calendar source controls with audio-only
      defaults, immediate capture shutdown, and profile/user-policy query intersection.
- [x] Show an explicit local-only processing policy and test that disabling audio
      prevents capture without turning an empty source list into an unrestricted query.
- [x] Add explicit Notion output for a selected SemanticArtifact behind Rust
      ActionProposal policy, confirmation UI, Keychain credentials, and adapter tests.
- [x] Add opt-in macOS Terminal and Chrome collectors, a local CLI composition root,
      lossless Chrome cursoring, Rust persistence, and content-free diagnostics.

## On hold

- [ ] Register or confirm `com.dayline.Dayline` in Apple Developer and App Store
      Connect, then configure signing Secrets after the vertical slice is proven.
- [ ] External LLM runtimes, independent backend, vector database, and autonomous
      agents remain outside the MVP.

## Technical debt and checks

- [ ] Add coverage thresholds after the vertical slice has meaningful integration
      coverage.
- [ ] Review GitHub Actions using deprecated Node.js 20 before the compatibility
      shim is removed.
- [ ] Measure bundled SQLite and IANA timezone binary-size impact in the XCFramework.

## Start here next time

1. Read `docs/adr/0001-context-platform-boundaries.md` and
   `docs/adr/0006-macos-context-collection.md`.
2. Read `docs/product-profiles.md`, `docs/capture.md`, and GitHub Issue #11.
3. Run `make ci`.
4. Audit every checkbox in Issue #11 against implementation and runtime/CI evidence;
   close only when all current-head workflows are green.
