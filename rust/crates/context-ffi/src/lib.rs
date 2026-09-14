#![doc = "Minimal `UniFFI` JSON boundary for `ContextCoreKit`."]

mod request;

use context_domain::{ContextBundle, ContextEvent, SemanticArtifact};
use context_engine::ContextEngine;
use context_store::ContextStore;
use request::BuildContextRequest;
use thiserror::Error;

uniffi::setup_scaffolding!();

#[derive(Debug, Error, uniffi::Error)]
pub enum ContextBridgeError {
    #[error("invalid context request")]
    InvalidRequest,

    #[error("context assembly failed")]
    AssemblyFailed,

    #[error("local persistence failed")]
    PersistenceFailed,
}

/// Builds a validated `ContextBundle` from a versioned JSON request.
///
/// # Errors
///
/// Returns a categorized error without exposing input content or local paths.
#[uniffi::export]
#[allow(clippy::needless_pass_by_value)] // UniFFI owns cross-language strings.
pub fn build_context_bundle(request_json: String) -> Result<String, ContextBridgeError> {
    let request: BuildContextRequest =
        serde_json::from_str(&request_json).map_err(|_| ContextBridgeError::InvalidRequest)?;
    let (plan, query, events, artifacts) = request.into_parts()?;
    let engine = ContextEngine::new().map_err(|_| ContextBridgeError::AssemblyFailed)?;
    let bundle = engine
        .build(plan, &query, &events, &artifacts)
        .map_err(|_| ContextBridgeError::AssemblyFailed)?;
    serde_json::to_string(&bundle).map_err(|_| ContextBridgeError::AssemblyFailed)
}

/// Shrinks an assembled bundle without introducing model-specific token semantics.
///
/// # Errors
///
/// Returns a categorized error for invalid JSON, invalid budgets, or serialization failure.
#[uniffi::export]
#[allow(clippy::needless_pass_by_value)] // UniFFI owns cross-language strings.
pub fn shrink_context_bundle(
    bundle_json: String,
    maximum_units: u64,
) -> Result<String, ContextBridgeError> {
    let bundle: ContextBundle =
        serde_json::from_str(&bundle_json).map_err(|_| ContextBridgeError::InvalidRequest)?;
    let shrunk = bundle
        .shrink_to(maximum_units)
        .map_err(|_| ContextBridgeError::AssemblyFailed)?;
    serde_json::to_string(&shrunk).map_err(|_| ContextBridgeError::AssemblyFailed)
}

/// Persists a validated, redacted `ContextEvent` and returns its canonical JSON.
///
/// # Errors
///
/// Returns a categorized error without exposing input content or local paths.
#[uniffi::export]
#[allow(clippy::needless_pass_by_value)] // UniFFI owns cross-language strings.
pub fn persist_context_event(
    database_path: String,
    event_json: String,
) -> Result<String, ContextBridgeError> {
    let event: ContextEvent =
        serde_json::from_str(&event_json).map_err(|_| ContextBridgeError::InvalidRequest)?;
    let mut store =
        ContextStore::open(database_path).map_err(|_| ContextBridgeError::PersistenceFailed)?;
    let saved = store
        .save_event(&event)
        .map_err(|_| ContextBridgeError::PersistenceFailed)?;
    serde_json::to_string(&saved).map_err(|_| ContextBridgeError::PersistenceFailed)
}

/// Persists a validated, redacted `SemanticArtifact` and returns canonical JSON.
///
/// # Errors
///
/// Returns a categorized error without exposing input content or local paths.
#[uniffi::export]
#[allow(clippy::needless_pass_by_value)] // UniFFI owns cross-language strings.
pub fn persist_semantic_artifact(
    database_path: String,
    artifact_json: String,
) -> Result<String, ContextBridgeError> {
    let artifact: SemanticArtifact =
        serde_json::from_str(&artifact_json).map_err(|_| ContextBridgeError::InvalidRequest)?;
    let mut store =
        ContextStore::open(database_path).map_err(|_| ContextBridgeError::PersistenceFailed)?;
    let saved = store
        .save_artifact(&artifact)
        .map_err(|_| ContextBridgeError::PersistenceFailed)?;
    serde_json::to_string(&saved).map_err(|_| ContextBridgeError::PersistenceFailed)
}
