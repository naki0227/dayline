# ADR 0005: UniFFI with a versioned JSON boundary

- Status: Accepted
- Date: 2026-09-14

## Context

Dayline needs to call the reusable Rust Context Engine and local store from Swift
on iOS and macOS. The four JSON Schemas already define the language-neutral API,
and Swift must keep Apple model concerns outside Rust.

## Problem

A handwritten C ABI requires memory-management code, while exporting every domain
type through FFI would duplicate schema evolution across Rust, generated Swift,
and hand-written DTOs. Generated artifacts must also work with Swift 6 and Xcode
26/27 without being committed as large binaries.

## Options

1. Handwrite C functions and buffer ownership.
2. Export every Rust domain type as a typed UniFFI API.
3. Pin UniFFI and export a narrow API carrying versioned JSON documents.

## Decision

Use option 3 with UniFFI 0.31.2 pinned in `Cargo.lock`. Export only three operations:

- build a `ContextBundle` from a versioned request;
- persist a `ContextEvent`;
- persist a `SemanticArtifact`.

Rust validates every JSON document and returns canonical JSON. FFI errors expose
only `invalid request`, `assembly failed`, or `persistence failed`; raw context and
local paths do not cross the error boundary. `ContextCoreKit` owns typed Swift DTOs,
while `ContextCoreFFIKit` owns generated bindings and binary linkage.

The XCFramework is generated, not committed. It contains arm64 iOS, arm64/x86_64
iOS Simulator, and arm64/x86_64 macOS slices. UniFFI 0.31.2 emits two builtin
module imports that are incompatible with current Xcode module discovery; the
build script removes only those module-map lines and fails if they remain.

## Reasons

- UniFFI owns buffer allocation, deallocation, checksums, and Swift error lifting.
- JSON Schema remains the single cross-language compatibility contract.
- A three-function surface limits ABI churn and generated code volume.
- Generated artifacts can be reproduced and tested in a dedicated CI workflow.
- Keeping FFI in its own package preserves ContextCoreKit's platform-neutral API.

## Benefits

- No handwritten unsafe C memory-management layer.
- Rust constructors and Store invariants remain authoritative.
- Swift can decode stable DTOs and map transport failures without leaking content.
- Real cross-language integration tests run on macOS and the binary includes iOS.

## Drawbacks

- JSON encoding adds allocation and parse cost at the boundary.
- UniFFI is pre-1.0 and pinned upgrades require generated-output review.
- The unoptimized static XCFramework is currently large because it contains five
  architecture builds and bundled SQLite/timezone data.
- The Xcode module-map compatibility workaround must be removed when upstream fixes
  the generated output.

## Revisit when

- profiling shows JSON serialization is a material live-transcription bottleneck;
- UniFFI changes its checksum or Swift concurrency contract;
- the upstream Xcode module-map issue is fixed;
- binary-size measurements require feature or symbol-level splitting.
