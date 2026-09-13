# Contracts

This directory owns versioned, language-neutral schemas crossing the Rust/Swift
boundary. `context-event.schema.json` defines observed facts and
`semantic-artifact.schema.json` defines model-derived meaning. Semantic artifacts
must reference at least one source event and record their generation provenance.
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
