# Dayline Todo

## In progress

- [ ] Confirm the exact AppleDevCLI executable and command contract intended for
      App Store delivery.

## Not started

- [ ] Define versioned `ContextEvent`, `SemanticArtifact`, `ContextBundle`, and
      `ActionProposal` schemas.
- [ ] Implement Rust domain invariants with unit tests.
- [ ] Add normalization, redaction, policy, query, ranking, assembly, and store
      crates incrementally with tests.
- [ ] Select and record the Rust/Swift FFI approach, then generate an XCFramework.
- [ ] Create the Dayline iOS app target and deterministic UI test harness.
- [ ] Add the macOS Terminal and Chrome collector boundaries.
- [ ] Add tag-based CD after bundle/team/App Store identifiers are confirmed.
- [ ] Add dependency and security auditing appropriate to Rust and Swift.

## Completed

- [x] Create the public GitHub repository.
- [x] Add separate blocking Rust and Swift CI workflows.
- [x] Add advisory code-duplication reporting.
- [x] Establish ContextCoreKit and AppleIntelligenceKit package boundaries.
- [x] Record the initial architecture decision.

## On hold

- [ ] External LLM runtimes, independent backend, vector database, and autonomous
      agents remain outside the MVP.

## Technical debt and checks

- [ ] Replace marker APIs with versioned generated bindings after the contracts
      are accepted.
- [ ] Add coverage thresholds after meaningful domain behavior exists.

## Start here next time

1. Read `docs/adr/0001-context-platform-boundaries.md`.
2. Read `docs/architecture.md` and `contracts/README.md`.
3. Run `make ci`.
4. Define the four v1 JSON schemas and their compatibility tests.

