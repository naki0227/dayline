use thiserror::Error;

/// Validation errors for data entering the platform-neutral domain.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum DomainError {
    #[error("{field} must not be empty")]
    EmptyField { field: &'static str },

    #[error("{field} must be a valid UUID")]
    InvalidUuid { field: &'static str },

    #[error("retention days must be greater than zero")]
    InvalidRetentionDays,
}
