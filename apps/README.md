# Apps

Product-specific Apple clients live here. Apps compose ContextCoreKit,
AppleIntelligenceKit, capture adapters, synchronization, and SwiftUI. Reusable
domain or model-runtime behavior does not belong in this directory.

`MacContextAgent` is the headless macOS composition root. It connects MacContextKit to
the Rust store and exposes local configuration, stdin-only shell ingestion, and Chrome
history polling without printing collected content.
