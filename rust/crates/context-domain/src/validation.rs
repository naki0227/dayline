use std::collections::HashSet;
use std::hash::Hash;

use crate::DomainError;

pub(crate) fn require_text(value: &str, field: &'static str) -> Result<(), DomainError> {
    if value.trim().is_empty() {
        return Err(DomainError::EmptyField { field });
    }
    Ok(())
}

pub(crate) fn require_identifier(value: &str, field: &'static str) -> Result<(), DomainError> {
    let mut bytes = value.bytes();
    let valid_start = bytes.next().is_some_and(|byte| byte.is_ascii_lowercase());
    let valid_tail = bytes.all(|byte| {
        byte.is_ascii_lowercase() || byte.is_ascii_digit() || matches!(byte, b'.' | b'_' | b'-')
    });
    if !valid_start || !valid_tail {
        return Err(DomainError::InvalidIdentifier { field });
    }
    Ok(())
}

pub(crate) fn require_non_empty<T>(values: &[T], field: &'static str) -> Result<(), DomainError> {
    if values.is_empty() {
        return Err(DomainError::EmptyCollection { field });
    }
    Ok(())
}

pub(crate) fn require_unique<T>(values: &[T], field: &'static str) -> Result<(), DomainError>
where
    T: Eq + Hash,
{
    let mut seen = HashSet::with_capacity(values.len());
    if values.iter().all(|value| seen.insert(value)) {
        return Ok(());
    }
    Err(DomainError::DuplicateIdentifier { field })
}
