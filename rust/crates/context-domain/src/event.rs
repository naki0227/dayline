use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use time::OffsetDateTime;

use crate::validation::require_text;
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

#[derive(Clone, Copy, Debug, Deserialize, Eq, Ord, PartialEq, PartialOrd, Serialize)]
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
    pub(crate) fn validate(self) -> Result<(), DomainError> {
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
#[serde(try_from = "RawContextEvent")]
pub struct ContextEvent {
    schema_version: u32,
    id: EventId,
    #[serde(with = "time::serde::rfc3339")]
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

    #[must_use]
    pub const fn id(&self) -> EventId {
        self.id
    }

    #[must_use]
    pub const fn occurred_at(&self) -> OffsetDateTime {
        self.occurred_at
    }

    #[must_use]
    pub const fn session_id(&self) -> Option<SessionId> {
        self.session_id
    }

    #[must_use]
    pub const fn source(&self) -> &ContextSource {
        &self.source
    }

    #[must_use]
    pub const fn payload(&self) -> &EventPayload {
        &self.payload
    }

    #[must_use]
    pub const fn sensitivity(&self) -> Sensitivity {
        self.sensitivity
    }
}

#[derive(Deserialize)]
struct RawContextEvent {
    schema_version: u32,
    id: EventId,
    #[serde(with = "time::serde::rfc3339")]
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
}

impl TryFrom<RawContextEvent> for ContextEvent {
    type Error = DomainError;

    fn try_from(raw: RawContextEvent) -> Result<Self, Self::Error> {
        if raw.schema_version != crate::CONTEXT_SCHEMA_VERSION {
            return Err(DomainError::UnsupportedSchemaVersion {
                expected: crate::CONTEXT_SCHEMA_VERSION,
                actual: raw.schema_version,
            });
        }
        Self::new(
            raw.id,
            raw.occurred_at,
            raw.day_id,
            raw.session_id,
            raw.source,
            raw.kind,
            raw.payload,
            raw.metadata,
            raw.sensitivity,
            raw.retention,
            raw.provenance,
        )
    }
}
