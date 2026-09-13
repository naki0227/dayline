use std::collections::HashSet;
use std::hash::Hash;

use crate::DomainError;

pub(crate) fn require_text(value: &str, field: &'static str) -> Result<(), DomainError> {
    if value.trim().is_empty() {
        return Err(DomainError::EmptyField { field });
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
    T: Copy + Eq + Hash,
{
    let mut seen = HashSet::with_capacity(values.len());
    if values.iter().copied().all(|value| seen.insert(value)) {
        return Ok(());
    }
    Err(DomainError::DuplicateIdentifier { field })
}
