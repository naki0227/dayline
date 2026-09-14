# Dayline Todo

## In progress

- [ ] Complete the vertical slice:
      `ContextEvent -> Rust ContextBundle -> ContextCoreKit -> AppleIntelligenceKit
      stub -> SemanticArtifact -> local persistence`.
- [ ] Select and record the Rust/Swift FFI approach, then generate a reproducible
      XCFramework and Swift bindings.

## Not started

- [ ] Add Swift runtime availability, actual model token measurement, deterministic
      shrink retry, structured output mapping, and error mapping.
- [ ] Add a deterministic UI test harness to the Dayline iOS target.
- [ ] Implement iPhone audio capture and incremental speech transcription.
- [ ] Add Daily and Live Meeting product profiles and presentation flows.
- [ ] Add Notion write and Calendar read/write adapters behind ActionProposal policy.
- [ ] Add Live Activity, App Intent, and Control Center capture controls.
- [ ] Add the macOS Terminal and Chrome collector boundaries.
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

## On hold

- [ ] Register or confirm `com.dayline.Dayline` in Apple Developer and App Store
      Connect, then configure signing Secrets after the vertical slice is proven.
- [ ] External LLM runtimes, independent backend, vector database, and autonomous
      agents remain outside the MVP.

## Technical debt and checks

- [ ] Replace marker Swift APIs with versioned generated bindings.
- [ ] Add coverage thresholds after the vertical slice has meaningful integration
      coverage.
- [ ] Review GitHub Actions using deprecated Node.js 20 before the compatibility
      shim is removed.
- [ ] Measure bundled SQLite and IANA timezone binary-size impact in the XCFramework.

## Start here next time

1. Read issue #1 and `docs/adr/0001-context-platform-boundaries.md`.
2. Read `docs/adr/0004-local-store-and-day-boundaries.md` and `docs/storage.md`.
3. Run `make ci`.
4. Write the FFI ADR and implement the smallest ContextEvent-to-ContextBundle call.
