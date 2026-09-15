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

The UI keeps explicit idle, generating, empty, runtime-unavailable, ready, and failed
states. Ready artifacts are decoded into summary, highlights, topics, decisions,
TODOs, ideas, and questions. Empty groups are omitted, the source evidence count is
visible, and legacy artifacts fall back to their plain summary.

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

Source declarations are also upper bounds, not grants. The query source list is the
intersection of the versioned profile and the user's persisted `DaylineSourcePolicy`.
Audio is the only default-enabled source. Browser, shell, and calendar are opt-in;
disabling audio immediately ends active Daily or Live capture. An empty intersection
returns an explicit disabled state before Rust is called.

Notion export is initiated only from a ready Daily artifact. ProductKit renders its
structured sections to Markdown and creates a versioned `notion.page.create`
ActionProposal containing source artifact/event IDs. Rust policy returns `ask`; the app
shows the target parent and sends only after explicit confirmation. The integration
revalidates the approved proposal immediately before the network request.

## Testing

Unit tests cover profile invariants, One Day boundaries, session queries, 30-second
scheduling, empty-context short circuits, runtime invocation, artifact persistence,
structured section decoding, legacy fallback, and presentation state. App UI tests
inject deterministic empty generators and audio sources so CI never depends on Apple
Intelligence, microphone permission, or private context outside the local process.
The Notion suite uses an in-memory HTTP transport and fake credential store; CI never
sends a real page or reads a developer token.
