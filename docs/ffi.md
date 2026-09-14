# Rust/Swift FFI

The FFI boundary is generated from `context-ffi` and consumed only by
`ContextCoreFFIKit`. `ContextCoreKit` and `AppleIntelligenceKit` do not import the
generated C module.

## Prerequisites

- Xcode command-line tools
- Rust 1.88 or newer
- Rust targets `aarch64-apple-ios`, `aarch64-apple-ios-sim`,
  `x86_64-apple-ios`, and `x86_64-apple-darwin`

Install missing targets with:

```bash
rustup target add aarch64-apple-ios aarch64-apple-ios-sim \
  x86_64-apple-ios x86_64-apple-darwin
```

## Generate and verify

```bash
make ffi-xcframework
make ffi-check
```

The generated XCFramework and Swift source live under ignored
`packages/ContextCoreFFIKit/.artifacts/` and `.generated/` directories. CI rebuilds
them from the locked Rust dependencies. Do not edit or commit generated files.

`make ffi-check` links the generated macOS slice into Swift and verifies the full
fixture flow from Event persistence through ContextBundle assembly, stub runtime
generation, and SemanticArtifact persistence. iOS device and simulator slices are
validated structurally by `xcodebuild -create-xcframework`.

## Upgrade policy

Change the pinned UniFFI version in a dedicated dependency commit. Regenerate all
slices, inspect the generated Swift/header/module map, run `make ffi-check`, and
record checksum/API changes before updating the application package graph.
