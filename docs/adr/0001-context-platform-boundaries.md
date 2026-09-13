# ADR 0001: Separate Context Engine, Apple runtime, and product UI

- Status: Accepted
- Date: 2026-09-13

## Context

Dayline combines long-running capture, local context processing, Apple on-device
models, and product-specific UI. The context selection capability should be
reusable by later developer, study, or sales applications.

## Problem

Coupling source collection, context ranking, model APIs, and SwiftUI would make
privacy policy difficult to test and would tie reusable logic to one Apple model
generation and one product.

## Options

1. Implement everything in the Dayline SwiftUI application.
2. Implement all logic in Swift packages.
3. Separate a platform-neutral Rust Context Engine, a Swift facade, an Apple
   Intelligence runtime package, and product apps.

## Decision

Use option 3. Rust stops at a versioned `ContextBundle`. Swift owns model
availability, token measurement, prompts, tools, and structured Apple model
output. Dayline owns capture use cases and presentation.

## Reasons

- Rust provides deterministic, testable processing shared across Apple clients.
- Swift keeps Apple frameworks and concurrency at the platform boundary.
- Versioned contracts make FFI changes reviewable and backward-compatible.
- Product behavior can vary through sources, AI profiles, and UI without forking
  the engine.

## Benefits

- Clear dependency direction and smaller test surfaces.
- Model runtimes and storage adapters remain replaceable.
- Privacy, permission, and redaction decisions do not depend on model output.
- Future apps can reuse ContextCore and AppleIntelligenceKit.

## Drawbacks

- Rust/Swift FFI and XCFramework builds add CI and release complexity.
- Cross-language schema evolution requires deliberate versioning.
- Debugging can cross process and language boundaries.

## Reconsider when

- FFI overhead prevents required live-update latency.
- Apple APIs cannot be represented safely across the selected FFI boundary.
- ContextCore has no second client after the MVP and its separation creates more
  maintenance cost than value.

