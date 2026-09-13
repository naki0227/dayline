use serde::{Deserialize, Serialize};
use time::Date;
use uuid::Uuid;

use crate::DomainError;

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
#[serde(transparent)]
pub struct EventId(Uuid);

impl EventId {
    /// Parses a stable event identifier.
    ///
    /// # Errors
    ///
    /// Returns [`DomainError::InvalidUuid`] when `value` is not a UUID.
    pub fn parse(value: &str) -> Result<Self, DomainError> {
        Uuid::parse_str(value)
            .map(Self)
            .map_err(|_| DomainError::InvalidUuid { field: "event_id" })
    }

    #[must_use]
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

impl Default for EventId {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
#[serde(transparent)]
pub struct SessionId(Uuid);

impl SessionId {
    /// Parses a stable live-session identifier.
    ///
    /// # Errors
    ///
    /// Returns [`DomainError::InvalidUuid`] when `value` is not a UUID.
    pub fn parse(value: &str) -> Result<Self, DomainError> {
        Uuid::parse_str(value)
            .map(Self)
            .map_err(|_| DomainError::InvalidUuid {
                field: "session_id",
            })
    }
}

#[derive(Clone, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
pub struct DayId {
    pub local_date: Date,
    pub timezone: String,
}

impl DayId {
    /// Creates a local calendar day with its IANA timezone identifier.
    ///
    /// # Errors
    ///
    /// Returns [`DomainError::EmptyField`] when `timezone` is blank.
    pub fn new(local_date: Date, timezone: impl Into<String>) -> Result<Self, DomainError> {
        let timezone = timezone.into();
        if timezone.trim().is_empty() {
            return Err(DomainError::EmptyField { field: "timezone" });
        }
        Ok(Self {
            local_date,
            timezone,
        })
    }
}

#[cfg(test)]
mod tests {
    use time::macros::date;

    use super::{DayId, EventId};
    use crate::DomainError;

    #[test]
    fn event_id_rejects_non_uuid_input() {
        assert_eq!(
            EventId::parse("not-an-id"),
            Err(DomainError::InvalidUuid { field: "event_id" })
        );
    }

    #[test]
    fn day_id_rejects_blank_timezone() {
        assert_eq!(
            DayId::new(date!(2026 - 09 - 13), "  "),
            Err(DomainError::EmptyField { field: "timezone" })
        );
    }
}
