# ADR 0006: opt-in local macOS context collection

- Status: Accepted
- Date: 2026-09-16

## Context

Phase 1 requires Terminal and Chrome context on macOS while preserving Dayline's
local-first boundary. Raw terminal output, keystrokes, credentials, and detailed browser
activity must not leak to logs or remote services.

## Problem

Dayline needs useful completed-command and browser-visit facts without Accessibility
screen scraping, a browser extension dependency, or direct persistence outside Rust.
Collection must stop cleanly when disabled and tolerate Chrome running concurrently.

## Options

1. Use Accessibility/event taps to watch Terminal and Chrome UI.
2. Build a Chrome extension and a privileged terminal daemon.
3. Use an explicit zsh completion hook plus read-only Chrome History SQLite polling,
   mapped by a reusable adapter and persisted through the existing Rust FFI.

## Decision

Choose option 3. `MacContextKit` owns policy, Chrome reading, and typed event mapping.
`MacContextAgent` owns paths and composes the adapter with `RustContextStore`.

The shell hook sends command, cwd, exit status, duration, and completion time as bounded
JSON over stdin. Chrome uses `visits JOIN urls` and a compound timestamp/visit-ID cursor.
Both sources default to disabled and are checked before source access. The integration
emits only v1 `shell_command` and `browser_visit` ContextEvents; Rust validates, redacts,
and persists them.

## Reasons

- Explicit hooks avoid capturing keystrokes and terminal output.
- Direct read-only history access avoids a mandatory extension and network service.
- Compound cursoring is deterministic across equal timestamps and repeated polls.
- The adapter remains testable without FFI; only the app composition root knows SQLite.

## Benefits

- Works locally without Notion, a server, or a browser account integration.
- Source disablement prevents reads as well as writes.
- Secret redaction and immutable persistence remain Rust-owned.
- Failures expose category codes without URLs, commands, paths, or database messages.

## Drawbacks

- The zsh hook is explicit setup and does not cover other shells without another hook.
- Chrome may require Full Disk Access and the default path covers only the Default
  profile unless a different History path is configured.
- Poll scheduling is delegated to a user LaunchAgent in Phase 1.

## Revisit when

- Dayline ships a signed macOS UI that can own login-item and permission setup;
- Chrome changes its History schema or storage access rules;
- another shell or browser becomes a Phase 1 requirement;
- a browser extension offers materially better consent or provenance.
