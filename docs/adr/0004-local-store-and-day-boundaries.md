# ADR 0004: Local SQLite store and IANA day boundaries

- Status: Accepted
- Date: 2026-09-14

## Context

Dayline must retain detailed personal context locally, group it into the user's
calendar day, and prevent terminal credentials from reaching disk. Events and
generated artifacts also need immutable IDs and auditable evidence links.

## Problem

An RFC 3339 offset alone does not define a durable local day because daylight
saving and timezone rules change. Storing only JSON documents would also leave
duplicate IDs, missing evidence, and artifact provenance cycles unchecked.

## Options

1. Store JSON files and trust producer-supplied `day_id` values.
2. Use platform persistence in Swift and duplicate contract validation there.
3. Use a Rust-owned SQLite adapter with IANA timezone validation, redaction, and
   normalized provenance edges.

## Decision

Use option 3. `context-time` derives and validates One Day using the bundled IANA
database. `context-store` validates the day, redacts all textual payload fields,
serializes the validated domain object, and writes it in SQLite. Artifact-to-event
and artifact-to-artifact evidence is stored in foreign-key tables. Writes are
immutable, duplicate IDs are rejected, and the artifact graph must remain acyclic.

The detailed SQLite file remains device-local and must not be copied through
iCloud. Cloud synchronization, when added, operates on explicitly allowed records
through a separate adapter.

## Reasons

- Rust owns the same privacy and domain invariants for every Apple client.
- Bundled SQLite produces consistent local behavior without a system-library
  version dependency.
- IANA resolution handles UTC offsets and daylight-saving boundaries correctly.
- Normalized evidence edges make integrity and cycle checks deterministic.

## Benefits

- Raw secrets are removed before persistence rather than at read time.
- Invalid days, missing evidence, duplicate records, and cycles fail atomically.
- JSON contracts remain inspectable while relational indexes support day queries.
- The store can be exercised without Apple frameworks in unit tests.

## Drawbacks

- Bundled SQLite and timezone data increase binary size and dependency surface.
- JSON documents and selected indexed columns are intentionally duplicated.
- Schema migration must keep relational indexes and JSON contracts aligned.
- SQLite remains a synchronous boundary and must run off the Swift main actor.

## Revisit when

- Device measurements show unacceptable binary size or write latency.
- Contract v2 needs indexed fields not represented by migration v1.
- Cloud synchronization requires a separate replicated record model.
- A supported Apple persistence API can preserve the same Rust-owned invariants.
