# Contracts

This directory owns versioned, language-neutral schemas crossing the Rust/Swift
boundary. `context-event.schema.json` defines observed facts and
`semantic-artifact.schema.json` defines model-derived meaning. Semantic artifacts
must reference at least one source Event or Artifact and record their generation
provenance.
`context-bundle.schema.json` defines policy-filtered, ranked model input without
duplicating canonical Event or Artifact records.
`action-proposal.schema.json` defines an unexecuted external side effect. Tool
arguments require a versioned registry schema, and destructive proposals require
explicit confirmation.

```bash
make contracts-venv
make contracts-check
```

Generated code must be reproducible and CI must reject stale generated output.

All four schemas are self-contained. Cross-record rules such as sensitivity
propagation, time ordering, abstract context-unit arithmetic, provenance graph
acyclicity, and IANA timezone day resolution are Rust invariants, not schema-only
guarantees. Actual model token measurement remains a Swift runtime concern. See
`docs/adr/0003-core-contracts-v1.md`.
