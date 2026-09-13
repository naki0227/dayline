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
| `rust/` | Platform-neutral context domain and engine |
| `packages/ContextCoreKit/` | Stable Swift facade over the Rust boundary |
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
```

CI is split by responsibility under `.github/workflows/`. Development is based
on small commits pushed directly to `main`; pull requests are not required.

## Current status

The repository currently contains the validated build and CI foundation. Product
features, Apple app targets, Rust/Swift FFI, and tag-based App Store delivery are
tracked in [`docs/TODO.md`](docs/TODO.md).

