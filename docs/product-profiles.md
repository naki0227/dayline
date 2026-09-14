# Product profiles

## Boundary

Dayline product behavior is expressed as `Sources + AI Profile + UI`.
`DaylineProductKit` owns the profile catalog, product use cases, and observable state;
Rust owns context selection and storage; `AppleIntelligenceKit` owns model execution;
the app owns platform composition and SwiftUI.

## Daily Summary v1

The Daily flow uses a timezone-derived half-open interval `[startOfDay, nextDay)`.
It builds a stored ContextBundle with the `daily-summary` profile, refuses to call the
model for an empty bundle, generates one traceable SemanticArtifact, and persists it
to the same Rust-owned SQLite store used by capture.

Current UI output is the artifact text with explicit idle, generating, empty,
runtime-unavailable, ready, and failed states. Structured cards for decisions, todos,
ideas, and questions remain Phase 1 work.

## Live Meeting v1

The Live profile defines the only incremental interval: 30 seconds. Its service
queries the Rust store by meeting session ID and audio source, sends non-empty context
through the runtime, and persists every generated state as a provenance-preserving
SemanticArtifact. The observable model schedules profile-driven updates and exposes
listening, updating, ready, empty, unavailable, and failed states.

The iOS view starts an independent streaming capture path, keeps an obvious red Live
indicator visible, shows the most recent volatile/final transcript or generated state,
and finalizes one last update when the meeting stops. Daily recording is stopped before
Live starts and vice versa to avoid competing audio-session ownership.

## Tools and permissions

Profile tool declarations are capability requests, not permission grants. Calendar
read and Notion write declarations become suggested tools in a ContextBundle. Any
external write must still become an ActionProposal and pass deterministic permission
evaluation before an integration may execute it.

## Testing

Unit tests cover profile invariants, One Day boundaries, session queries, 30-second
scheduling, empty-context short circuits, runtime invocation, artifact persistence,
and presentation state. App UI tests inject deterministic empty generators and audio
sources so CI never depends on Apple Intelligence, microphone permission, or private
context outside the local process.
