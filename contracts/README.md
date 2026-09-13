# Contracts

This directory owns versioned, language-neutral schemas crossing the Rust/Swift
boundary. `context-event.schema.json` defines the first v1 observation contract;
its fixture is also used by the Rust serialization test.

```bash
make contracts-venv
make contracts-check
```

Future contract sets will define SemanticArtifact, ContextBundle, and
ActionProposal. Generated code must be reproducible and CI must reject stale
generated output.
