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
Event-to-Artifact vertical slice. Product features are tracked in
[`docs/TODO.md`](docs/TODO.md).
