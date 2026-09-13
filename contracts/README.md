# Contracts

This directory owns versioned, language-neutral schemas crossing the Rust/Swift
boundary. `context-event.schema.json` defines observed facts and
`semantic-artifact.schema.json` defines model-derived meaning. Semantic artifacts
must reference at least one source event and record their generation provenance.

```bash
make contracts-venv
make contracts-check
```

Future contract sets will define ContextBundle and ActionProposal. Generated code
must be reproducible and CI must reject stale generated output.
