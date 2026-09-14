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

The Live profile is defined and validated with a 30-second incremental interval, but
the streaming session pipeline and presentation are not yet implemented. Live must
use session IDs and volatile/final transcript separation; completed audio-file
transcription remains the Daily capture path.

## Tools and permissions

Profile tool declarations are capability requests, not permission grants. Calendar
read and Notion write declarations become suggested tools in a ContextBundle. Any
external write must still become an ActionProposal and pass deterministic permission
evaluation before an integration may execute it.

## Testing

Unit tests cover profile invariants, One Day boundaries, empty-context short circuit,
runtime invocation, artifact persistence, and presentation state. App UI tests inject
a deterministic empty-day generator so CI never depends on Apple Intelligence
availability or sends private context outside the local process.
