# Privacy and source controls

## Defaults

- Detailed ContextEvent and SemanticArtifact records remain in Rust-owned local SQLite.
- Apple Speech and Foundation Models processing is on-device.
- Audio is enabled by default. Browser, shell, and calendar are opt-in.
- No external destination receives data merely because a profile names a tool.
- macOS shell and browser collectors are independently disabled by default.

## Enforcement

`DaylineSourcePolicy` is a typed ProductKit value shared through an actor. Daily query
sources are the intersection of this user allowlist and the versioned AI profile. Live
Meeting additionally requires audio. If no source is allowed, ProductKit fails closed
before invoking Rust because an empty Rust source filter intentionally means all
sources.

The app persists only the enabled source identifiers in UserDefaults. When audio is
disabled, it first stops active Daily and Live audio owners, then publishes and saves
the new policy. SwiftUI displays policy state but does not make authorization choices.

## Off-device rule

External output must be a separate, explicit user operation. A generated
SemanticArtifact must first become an ActionProposal and pass deterministic policy;
credentials stay in platform-secure storage and outside model context. Raw audio,
transcripts, browser history, terminal context, database paths, and signing identifiers
must not be logged or sent by default.

## Notion output

Notion export sends only the selected SemanticArtifact's rendered summary sections and
provenance identifiers. It does not send raw audio, full transcript records, browser or
terminal history, the SQLite path, or signing configuration. Rust evaluates the
ActionProposal before the confirmation prompt and again immediately before execution.

The Notion access/refresh token pair and revocation capability are stored as one
versioned record with a device-only Keychain accessibility class and are never persisted
in UserDefaults. OAuth authorization-code exchange and the Notion client secret stay
behind an HTTPS broker; the app callback carries only an opaque session ID. The parent
page ID is non-secret configuration and may be stored in UserDefaults. User-facing and
internal integration errors are finite, content-free categories; response bodies and
credentials are not logged.

The macOS shell hook records only completed command metadata and sends it to the local
agent over stdin. It never captures stdout, stderr, or individual keystrokes. Chrome is
read-only and limited to HTTP(S) visit URL/title/time. Policy is checked before either
stdin is read or the Chrome database is opened. Commands still pass through Rust
redaction before storage, and collector errors never include observed content or paths.
