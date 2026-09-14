# ADR 0003: Core Contracts v1

- Status: Accepted
- Date: 2026-09-13
- Clarified: 2026-09-14

## Context

Dayline needs a stable, language-neutral boundary between context collection,
the Rust Context Engine, Swift adapters, model runtimes, and integrations. Raw
observations, generated meaning, model input, and proposed side effects have
different trust and lifecycle rules.

## Problem

A single flexible record would make it difficult to distinguish evidence from
model output, trace generations to their inputs, enforce privacy policy before
model use, or prevent an AI response from directly causing an external write.

## Options

1. Use one extensible record with a free-form payload.
2. Expose Rust-native types directly over FFI.
3. Define four strict JSON Schema contracts with explicit provenance and IDs.

## Decision

Use option 3 with JSON Schema Draft 2020-12:

- `ContextEvent` stores an observed fact and collection provenance.
- `SemanticArtifact` stores generated meaning and references one or more source
  Event or Artifact IDs. Artifact provenance is an acyclic graph.
- `ContextBundle` stores ordered, policy-filtered, model-ready items that cite
  canonical Event or Artifact IDs.
- `ActionProposal` stores only an unexecuted external side effect. Deterministic
  policy evaluation remains mandatory before execution.

Every record carries `schema_version: 1`, rejects unknown object properties, and
uses RFC 3339 timestamps and UUID identifiers. Schemas remain self-contained in
v1: small shared definitions are duplicated intentionally so a consumer can
validate one contract without a remote schema registry. Breaking revisions must
be introduced alongside v1 rather than changing its meaning in place.

Tool arguments remain integration-specific. An ActionProposal therefore names a
versioned argument schema; the Tool Registry must validate it before policy or
execution. Destructive proposals require explicit confirmation at the schema
boundary.

Cross-record and cross-field rules that JSON Schema cannot express reliably,
such as sensitivity propagation, time ordering, abstract estimate-budget
arithmetic, unique record IDs inside a bundle, and artifact graph acyclicity,
belong in Rust constructors and persistence boundaries. Rust does not reserve or
measure model tokens. Swift measures the assembled bundle against the selected
runtime and requests a smaller bundle when required.

## Benefits

- Evidence and generated claims cannot be confused by record type.
- Every derived value and proposed action is traceable to canonical inputs.
- Swift, Rust, tests, and future clients can share fixtures.
- Model runtime and integration details stay outside the Rust core contracts.
- Safety checks happen before any external side effect.

## Drawbacks

- Some definitions repeat across standalone schemas.
- Schema and generated binding migrations require explicit compatibility work.
- JSON Schema alone cannot enforce every domain invariant.
- Generic tool arguments need a second registry validation step.

## Revisit when

- Repeated definitions drift often enough to justify a bundled schema catalog.
- A second contract version requires a formal migration and compatibility tool.
- Generated Rust and Swift bindings reveal JSON Schema representation limits.
- Tool Registry requirements need a dedicated contract family.
