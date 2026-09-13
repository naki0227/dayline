# Dayline Todo

## In progress

- [ ] Register or confirm `com.dayline.Dayline` in Apple Developer and App Store
      Connect, then configure the remaining GitHub Secrets.

## Not started

- [ ] Implement Rust `SemanticArtifact`, `ContextBundle`, and `ActionProposal`
      invariants with unit tests.
- [ ] Add normalization, redaction, policy, query, ranking, assembly, and store
      crates incrementally with tests.
- [ ] Select and record the Rust/Swift FFI approach, then generate an XCFramework.
- [ ] Add a deterministic UI test harness to the Dayline iOS target.
- [ ] Add the macOS Terminal and Chrome collector boundaries.
- [ ] Add Swift dependency auditing when third-party Swift dependencies are introduced.

## Completed

- [x] Create the public GitHub repository.
- [x] Add separate blocking Rust and Swift CI workflows.
- [x] Add advisory code-duplication reporting.
- [x] Establish ContextCoreKit and AppleIntelligenceKit package boundaries.
- [x] Record the initial architecture decision.
- [x] Confirm “AppleDevCLI” means the `useful_map` release toolchain.
- [x] Add the minimal Dayline iOS target and unsigned CI build.
- [x] Add Makefile-driven dry-run and upload release paths.
- [x] Add tag-based App Store CD and secret scanning.
- [x] Add Rust and Python release-tool dependency audits.
- [x] Define and validate the `ContextEvent` v1 JSON Schema and fixture.
- [x] Implement validated Rust `ContextEvent` domain types and serialization.
- [x] Define and validate all four v1 core contracts with positive and negative
      fixtures.
- [x] Record the v1 contract boundary and versioning decisions in ADR 0003.

## On hold

- [ ] External LLM runtimes, independent backend, vector database, and autonomous
      agents remain outside the MVP.

## Technical debt and checks

- [ ] Replace marker APIs with versioned generated bindings after the contracts
      are accepted.
- [ ] Add coverage thresholds after meaningful domain behavior exists.
- [ ] Review GitHub Actions using the deprecated Node.js 20 runtime before the
      runner compatibility shim is removed.

## Start here next time

1. Read `docs/adr/0001-context-platform-boundaries.md`.
2. Read `docs/architecture.md` and `contracts/README.md`.
3. Run `make ci`.
4. Implement the Rust `SemanticArtifact` model and source-event invariants.
