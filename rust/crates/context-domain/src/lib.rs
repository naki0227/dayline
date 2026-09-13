#![doc = "Platform-neutral domain contracts for the Dayline context engine."]

mod error;
mod event;
mod identifiers;

pub use error::DomainError;
pub use event::{
    ContextEvent, ContextSource, EventKind, EventPayload, Provenance, RetentionPolicy, Sensitivity,
};
pub use identifiers::{DayId, EventId, SessionId};

/// Current version of the cross-language context contract.
pub const CONTEXT_SCHEMA_VERSION: u32 = 1;
