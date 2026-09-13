use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use time::OffsetDateTime;

use crate::{DayId, DomainError, EventId, SessionId};

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case", tag = "type", content = "identifier")]
pub enum ContextSource {
    Audio,
    Browser,
    Shell,
    Calendar,
    GitHub,
    Notion,
    External(String),
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum EventKind {
    Transcript,
    Command,
    Visit,
    CalendarEvent,
    Message,
    External,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case", tag = "type", content = "content")]
pub enum EventPayload {
    Text {
        text: String,
    },
    ShellCommand {
        command: String,
        cwd: String,
        exit_code: Option<i32>,
        duration_ms: Option<u64>,
    },
    BrowserVisit {
        url: String,
        title: Option<String>,
    },
}

impl EventPayload {
    fn validate(&self) -> Result<(), DomainError> {
        match self {
            Self::Text { text } => require_text(text, "payload.text"),
            Self::ShellCommand { command, cwd, .. } => {
                require_text(command, "payload.command")?;
                require_text(cwd, "payload.cwd")
            }
            Self::BrowserVisit { url, .. } => require_text(url, "payload.url"),
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Sensitivity {
    Standard,
    Sensitive,
    Restricted,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case", tag = "type", content = "days")]
pub enum RetentionPolicy {
    Session,
    Days(u16),
    Indefinite,
}

impl RetentionPolicy {
    fn validate(self) -> Result<(), DomainError> {
        if matches!(self, Self::Days(0)) {
            return Err(DomainError::InvalidRetentionDays);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct Provenance {
    pub collector: String,
    pub device_id: String,
    #[serde(with = "time::serde::rfc3339")]
    pub captured_at: OffsetDateTime,
}

impl Provenance {
    fn validate(&self) -> Result<(), DomainError> {
        require_text(&self.collector, "provenance.collector")?;
        require_text(&self.device_id, "provenance.device_id")
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ContextEvent {
    pub schema_version: u32,
    pub id: EventId,
    #[serde(with = "time::serde::rfc3339")]
    pub occurred_at: OffsetDateTime,
    pub day_id: DayId,
    pub session_id: Option<SessionId>,
    pub source: ContextSource,
    pub kind: EventKind,
    pub payload: EventPayload,
    pub metadata: BTreeMap<String, String>,
    pub sensitivity: Sensitivity,
    pub retention: RetentionPolicy,
    pub provenance: Provenance,
}

impl ContextEvent {
    /// Creates a validated context observation.
    ///
    /// # Errors
    ///
    /// Returns [`DomainError`] when payload, retention, provenance, or external source
    /// invariants are violated.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: EventId,
        occurred_at: OffsetDateTime,
        day_id: DayId,
        session_id: Option<SessionId>,
        source: ContextSource,
        kind: EventKind,
        payload: EventPayload,
        metadata: BTreeMap<String, String>,
        sensitivity: Sensitivity,
        retention: RetentionPolicy,
        provenance: Provenance,
    ) -> Result<Self, DomainError> {
        payload.validate()?;
        retention.validate()?;
        provenance.validate()?;
        if let ContextSource::External(identifier) = &source {
            require_text(identifier, "source.identifier")?;
        }
        Ok(Self {
            schema_version: crate::CONTEXT_SCHEMA_VERSION,
            id,
            occurred_at,
            day_id,
            session_id,
            source,
            kind,
            payload,
            metadata,
            sensitivity,
            retention,
            provenance,
        })
    }
}

fn require_text(value: &str, field: &'static str) -> Result<(), DomainError> {
    if value.trim().is_empty() {
        return Err(DomainError::EmptyField { field });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use time::macros::{date, datetime};

    use super::{
        ContextEvent, ContextSource, EventKind, EventPayload, Provenance, RetentionPolicy,
        Sensitivity,
    };
    use crate::{DayId, DomainError, EventId};

    fn event(
        payload: EventPayload,
        retention: RetentionPolicy,
    ) -> Result<ContextEvent, DomainError> {
        ContextEvent::new(
            EventId::parse("018f6ea2-8f44-7f00-8000-000000000001")?,
            datetime!(2026-09-13 10:31:00 +09:00),
            DayId::new(date!(2026 - 09 - 13), "Asia/Tokyo")?,
            None,
            ContextSource::Shell,
            EventKind::Command,
            payload,
            BTreeMap::from([("redacted".to_owned(), "true".to_owned())]),
            Sensitivity::Sensitive,
            retention,
            Provenance {
                collector: "context-collector".to_owned(),
                device_id: "mac-local".to_owned(),
                captured_at: datetime!(2026-09-13 10:31:01 +09:00),
            },
        )
    }

    #[test]
    fn rejects_empty_shell_command() {
        let result = event(
            EventPayload::ShellCommand {
                command: " ".to_owned(),
                cwd: "/workspace".to_owned(),
                exit_code: Some(1),
                duration_ms: Some(120),
            },
            RetentionPolicy::Days(30),
        );

        assert_eq!(
            result,
            Err(DomainError::EmptyField {
                field: "payload.command"
            })
        );
    }

    #[test]
    fn rejects_zero_day_retention() {
        let result = event(
            EventPayload::Text {
                text: "context".to_owned(),
            },
            RetentionPolicy::Days(0),
        );

        assert_eq!(result, Err(DomainError::InvalidRetentionDays));
    }

    #[test]
    fn serializes_to_the_v1_fixture() -> Result<(), Box<dyn std::error::Error>> {
        let value = serde_json::to_value(event(
            EventPayload::ShellCommand {
                command: "cargo test".to_owned(),
                cwd: "/workspace/dayline".to_owned(),
                exit_code: Some(0),
                duration_ms: Some(425),
            },
            RetentionPolicy::Days(30),
        )?)?;
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../../../../contracts/fixtures/context-event-v1.json"
        ))?;

        assert_eq!(value, fixture);
        Ok(())
    }
}
