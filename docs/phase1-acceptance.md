# Phase 1 acceptance evidence

GitHub Issue #11 is the authoritative Phase 1 scope. Each acceptance criterion maps to
an implementation boundary and an automated or runtime check below.

| Criterion | Implementation evidence | Verification evidence |
| --- | --- | --- |
| Event-to-artifact vertical slice | Rust store/engine, ContextCoreFFIKit, AppleIntelligenceKit | `completesTheEventToArtifactPersistenceSlice`; FFI and Swift workflows |
| Long-running iPhone capture and interruption recovery | ContextCaptureKit chunk recorder/coordinator | capture unit tests; Apple App start/stop UI test |
| Incremental Live Meeting state | live speech stream, session evidence, 30-second ProductKit loop | Live coordinator/service tests; persistent-state UI test |
| One Day Daily Summary | timezone-bounded Rust query and DailySummaryService | day-boundary/domain tests; Daily Product/UI tests |
| Artifact provenance | v1 source IDs, Rust evidence FKs/cycle checks, runtime factory | contract/domain/store/runtime tests |
| Obvious active recording state | red waveform/status and persistent Live indicator | Apple App UI tests |
| Explicit Notion destination | ActionProposal policy, confirmation UI, Keychain/HTTP adapter | Product/FFI/Notion tests; confirmation UI test |
| Enabled macOS Terminal and Chrome collection | MacContextKit, agent, zsh hook, read-only History polling | collector tests; real CLI-to-Rust isolated smoke test |
| Local usability without integrations | Rust SQLite canonical store; capture/summary independent of Notion | empty/unavailable Product/UI tests; Notion failures isolated |
| No Phase 2+ expansion | architecture docs, TODO hold list, issue-driven scope | architecture workflow and this audit |

## Additional scoped requirements

- Japanese/English requests are carried explicitly by Daily/Live profiles and prompt
  rendering; structured output remains language-neutral at the contract boundary.
- Audio, transcripts, browser, and shell details stay local by default. Source policy
  fails closed, Notion requires confirmation, and connector errors are content-free.
- iOS remains deployable at iOS 18; SpeechAnalyzer/Foundation Models features are
  availability-isolated on iOS 26+.
- CI is split by Rust, Swift, FFI, Apple App, Integrations, Contracts, Architecture,
  Release Tools, Security, and advisory cross-cutting quality responsibilities.

## Completion gate

Phase 1 is releasable only when all blocking workflows for the current `main` head are
green. The advisory duplication workflow may report findings without stopping delivery,
as intentionally recorded in the repository quality policy.
