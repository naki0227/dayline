use thiserror::Error;

/// Validation errors for data entering the platform-neutral domain.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum DomainError {
    #[error("{field} must not be empty")]
    EmptyField { field: &'static str },

    #[error("{field} must be a valid UUID")]
    InvalidUuid { field: &'static str },

    #[error("{field} must contain at least one item")]
    EmptyCollection { field: &'static str },

    #[error("{field} must not contain duplicate identifiers")]
    DuplicateIdentifier { field: &'static str },

    #[error("{field} must be greater than zero")]
    InvalidVersion { field: &'static str },

    #[error("confidence must be finite and between zero and one")]
    InvalidConfidence,

    #[error("{field} is not a valid contract identifier")]
    InvalidIdentifier { field: &'static str },

    #[error("{field} must be within its allowed range")]
    ValueOutOfRange { field: &'static str },

    #[error("time window end must be later than start")]
    InvalidTimeWindow,

    #[error("token budget exceeds its maximum")]
    TokenBudgetExceeded,

    #[error("included token count does not match the context items")]
    TokenCountMismatch,

    #[error("proposal expiration must be later than its proposal time")]
    InvalidExpiration,

    #[error("delete effects must be marked destructive")]
    DeleteMustBeDestructive,

    #[error("destructive proposals require explicit confirmation")]
    DestructiveConfirmationRequired,

    #[error("{field} exceeds the maximum length of {maximum}")]
    StringTooLong { field: &'static str, maximum: usize },

    #[error("unsupported schema version {actual}; expected {expected}")]
    UnsupportedSchemaVersion { expected: u32, actual: u32 },

    #[error("retention days must be greater than zero")]
    InvalidRetentionDays,
}
