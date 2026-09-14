use context_domain::DomainError;
use context_redact::RedactionError;
use context_time::DayBoundaryError;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum StoreError {
    #[error(transparent)]
    Database(#[from] rusqlite::Error),

    #[error(transparent)]
    Serialization(#[from] serde_json::Error),

    #[error(transparent)]
    Domain(#[from] DomainError),

    #[error(transparent)]
    Redaction(#[from] RedactionError),

    #[error(transparent)]
    DayBoundary(#[from] DayBoundaryError),

    #[error("{record_type} already exists: {id}")]
    DuplicateRecord {
        record_type: &'static str,
        id: String,
    },

    #[error("source event does not exist: {0}")]
    MissingSourceEvent(String),

    #[error("source artifact does not exist: {0}")]
    MissingSourceArtifact(String),

    #[error("semantic artifact provenance graph contains a cycle")]
    ArtifactCycle,
}
