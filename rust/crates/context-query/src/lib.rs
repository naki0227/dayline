#![doc = "Deterministic filtering criteria for context selection."]

use context_domain::{ContextEvent, ContextSource, SemanticArtifact, Sensitivity, SessionId};
use thiserror::Error;
use time::OffsetDateTime;

#[derive(Debug, Error, Eq, PartialEq)]
pub enum QueryError {
    #[error("query end must be later than start")]
    InvalidTimeRange,

    #[error("maximum context units must be greater than zero")]
    InvalidContextLimit,

    #[error("project hint must not be blank")]
    BlankProjectHint,
}

#[derive(Clone, Debug)]
pub struct ContextQuery {
    start: OffsetDateTime,
    end: OffsetDateTime,
    sources: Vec<ContextSource>,
    session_id: Option<SessionId>,
    project_hint: Option<String>,
    maximum_sensitivity: Sensitivity,
    maximum_context_units: u64,
}

impl ContextQuery {
    /// Creates validated selection and budget criteria.
    ///
    /// An empty source list selects every source. `session_id` narrows both Events
    /// and Artifacts to one live session.
    ///
    /// # Errors
    ///
    /// Returns a typed error for an invalid range, budget, or blank project hint.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        start: OffsetDateTime,
        end: OffsetDateTime,
        sources: Vec<ContextSource>,
        session_id: Option<SessionId>,
        project_hint: Option<String>,
        maximum_sensitivity: Sensitivity,
        maximum_context_units: u64,
    ) -> Result<Self, QueryError> {
        if end <= start {
            return Err(QueryError::InvalidTimeRange);
        }
        if maximum_context_units == 0 {
            return Err(QueryError::InvalidContextLimit);
        }
        if project_hint
            .as_ref()
            .is_some_and(|hint| hint.trim().is_empty())
        {
            return Err(QueryError::BlankProjectHint);
        }
        Ok(Self {
            start,
            end,
            sources,
            session_id,
            project_hint,
            maximum_sensitivity,
            maximum_context_units,
        })
    }

    #[must_use]
    pub fn matches_event(&self, event: &ContextEvent) -> bool {
        self.includes_time(event.occurred_at())
            && self.includes_session(event.session_id())
            && event.sensitivity() <= self.maximum_sensitivity
            && (self.sources.is_empty() || self.sources.contains(event.source()))
    }

    #[must_use]
    pub fn matches_artifact(&self, artifact: &SemanticArtifact) -> bool {
        self.includes_time(artifact.created_at())
            && self.includes_session(artifact.session_id())
            && artifact.sensitivity() <= self.maximum_sensitivity
    }

    #[must_use]
    pub fn project_hint(&self) -> Option<&str> {
        self.project_hint.as_deref()
    }

    #[must_use]
    pub const fn maximum_context_units(&self) -> u64 {
        self.maximum_context_units
    }

    #[must_use]
    pub const fn start(&self) -> OffsetDateTime {
        self.start
    }

    #[must_use]
    pub const fn end(&self) -> OffsetDateTime {
        self.end
    }

    fn includes_time(&self, value: OffsetDateTime) -> bool {
        value >= self.start && value < self.end
    }

    fn includes_session(&self, value: Option<SessionId>) -> bool {
        self.session_id.is_none() || self.session_id == value
    }
}

#[cfg(test)]
mod tests {
    use context_domain::{ContextEvent, SemanticArtifact, Sensitivity};
    use time::macros::datetime;

    use super::{ContextQuery, QueryError};

    const EVENT: &str = include_str!("../../../../contracts/fixtures/context-event-v1.json");
    const ARTIFACT: &str = include_str!("../../../../contracts/fixtures/semantic-artifact-v1.json");

    fn query(maximum_sensitivity: Sensitivity) -> Result<ContextQuery, QueryError> {
        ContextQuery::new(
            datetime!(2026-09-13 00:00:00 +09:00),
            datetime!(2026-09-14 00:00:00 +09:00),
            Vec::new(),
            None,
            Some("dayline".to_owned()),
            maximum_sensitivity,
            4096,
        )
    }

    #[test]
    fn matches_records_in_half_open_window() -> Result<(), Box<dyn std::error::Error>> {
        let event: ContextEvent = serde_json::from_str(EVENT)?;
        let artifact: SemanticArtifact = serde_json::from_str(ARTIFACT)?;
        let query = query(Sensitivity::Sensitive)?;
        assert!(query.matches_event(&event));
        assert!(query.matches_artifact(&artifact));
        Ok(())
    }

    #[test]
    fn excludes_records_above_sensitivity_ceiling() -> Result<(), Box<dyn std::error::Error>> {
        let event: ContextEvent = serde_json::from_str(EVENT)?;
        assert!(!query(Sensitivity::Standard)?.matches_event(&event));
        Ok(())
    }

    #[test]
    fn rejects_invalid_range_and_budget() {
        let at = datetime!(2026-09-13 00:00:00 +09:00);
        assert_eq!(
            ContextQuery::new(at, at, Vec::new(), None, None, Sensitivity::Standard, 10)
                .map(|_| ()),
            Err(QueryError::InvalidTimeRange)
        );
        assert_eq!(
            ContextQuery::new(
                at,
                datetime!(2026-09-14 00:00:00 +09:00),
                Vec::new(),
                None,
                None,
                Sensitivity::Standard,
                0,
            )
            .map(|_| ()),
            Err(QueryError::InvalidContextLimit)
        );
    }
}
