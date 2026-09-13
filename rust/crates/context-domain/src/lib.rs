#![doc = "Platform-neutral domain contracts for the Dayline context engine."]

mod artifact;
mod error;
mod event;
mod identifiers;
mod validation;

pub use artifact::{ArtifactKind, GenerationProvenance, SemanticArtifact, SemanticContent};
pub use error::DomainError;
pub use event::{
    ContextEvent, ContextSource, EventKind, EventPayload, Provenance, RetentionPolicy, Sensitivity,
};
pub use identifiers::{
    ArtifactId, BundleId, DayId, EventId, ProposalId, RecordId, RunId, SessionId,
};

/// Current version of the cross-language context contract.
pub const CONTEXT_SCHEMA_VERSION: u32 = 1;
