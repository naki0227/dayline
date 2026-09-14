#![doc = "IANA timezone-aware One Day boundary validation."]

use context_domain::{ContextEvent, DayId, DomainError, SemanticArtifact};
use thiserror::Error;
use time::{Date, OffsetDateTime};
use time_tz::{OffsetDateTimeExt, timezones};

#[derive(Debug, Error, Eq, PartialEq)]
pub enum DayBoundaryError {
    #[error("unknown IANA timezone: {timezone}")]
    UnknownTimezone { timezone: String },

    #[error("day_id date {actual} does not match {expected} in timezone {timezone}")]
    DateMismatch {
        actual: Date,
        expected: Date,
        timezone: String,
    },

    #[error(transparent)]
    Domain(#[from] DomainError),
}

/// Resolves a timestamp to its local calendar day using the bundled IANA data.
///
/// # Errors
///
/// Returns an error when the timezone name is unknown or the resulting Day ID
/// violates a domain invariant.
pub fn resolve_day_id(
    timestamp: OffsetDateTime,
    timezone: &str,
) -> Result<DayId, DayBoundaryError> {
    let zone =
        timezones::get_by_name(timezone).ok_or_else(|| DayBoundaryError::UnknownTimezone {
            timezone: timezone.to_owned(),
        })?;
    DayId::new(timestamp.to_timezone(zone).date(), timezone).map_err(DayBoundaryError::from)
}

/// Verifies that a stored Day ID is derived from the timestamp and IANA zone.
///
/// # Errors
///
/// Returns an error for an unknown timezone or mismatched local date.
pub fn validate_day_id(timestamp: OffsetDateTime, day_id: &DayId) -> Result<(), DayBoundaryError> {
    let expected = resolve_day_id(timestamp, day_id.timezone())?;
    if expected.local_date() != day_id.local_date() {
        return Err(DayBoundaryError::DateMismatch {
            actual: day_id.local_date(),
            expected: expected.local_date(),
            timezone: day_id.timezone().to_owned(),
        });
    }
    Ok(())
}

/// Applies One Day validation to an observed event before persistence.
///
/// # Errors
///
/// Returns the same errors as [`validate_day_id`].
pub fn validate_event_day(event: &ContextEvent) -> Result<(), DayBoundaryError> {
    validate_day_id(event.occurred_at(), event.day_id())
}

/// Applies One Day validation to generated meaning before persistence.
///
/// # Errors
///
/// Returns the same errors as [`validate_day_id`].
pub fn validate_artifact_day(artifact: &SemanticArtifact) -> Result<(), DayBoundaryError> {
    validate_day_id(artifact.created_at(), artifact.day_id())
}

#[cfg(test)]
mod tests {
    use context_domain::{ContextEvent, DayId, SemanticArtifact};
    use time::macros::{date, datetime};

    use super::{DayBoundaryError, resolve_day_id, validate_artifact_day, validate_event_day};

    const EVENT: &str = include_str!("../../../../contracts/fixtures/context-event-v1.json");
    const ARTIFACT: &str = include_str!("../../../../contracts/fixtures/semantic-artifact-v1.json");

    #[test]
    fn resolves_the_same_instant_to_each_local_day() -> Result<(), Box<dyn std::error::Error>> {
        let instant = datetime!(2026-03-08 04:30:00 UTC);
        assert_eq!(
            resolve_day_id(instant, "Asia/Tokyo")?.local_date(),
            date!(2026 - 03 - 08)
        );
        assert_eq!(
            resolve_day_id(instant, "America/New_York")?.local_date(),
            date!(2026 - 03 - 07)
        );
        Ok(())
    }

    #[test]
    fn validates_fixture_event_and_artifact_days() -> Result<(), Box<dyn std::error::Error>> {
        let event: ContextEvent = serde_json::from_str(EVENT)?;
        let artifact: SemanticArtifact = serde_json::from_str(ARTIFACT)?;
        validate_event_day(&event)?;
        validate_artifact_day(&artifact)?;
        Ok(())
    }

    #[test]
    fn rejects_unknown_timezone_and_mismatched_date() -> Result<(), Box<dyn std::error::Error>> {
        let unknown = DayId::new(date!(2026 - 09 - 13), "Mars/Olympus")?;
        assert!(matches!(
            super::validate_day_id(datetime!(2026-09-13 00:00:00 UTC), &unknown),
            Err(DayBoundaryError::UnknownTimezone { .. })
        ));

        let mismatch = DayId::new(date!(2026 - 09 - 12), "Asia/Tokyo")?;
        assert!(matches!(
            super::validate_day_id(datetime!(2026-09-13 00:00:00 UTC), &mismatch),
            Err(DayBoundaryError::DateMismatch { .. })
        ));
        Ok(())
    }
}
