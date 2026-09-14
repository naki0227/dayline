use context_domain::{
    ContentFormat, ContextEvent, ContextRecordType, RecordId, SemanticArtifact, Sensitivity,
};
use context_normalize::{deduplication_key, estimate_units, normalize_model_text};
use context_redact::SecretRedactor;
use time::OffsetDateTime;

use crate::EngineError;

#[derive(Clone, Debug)]
pub(crate) struct Candidate {
    pub record_type: ContextRecordType,
    pub record_id: RecordId,
    pub occurred_at: OffsetDateTime,
    pub content: String,
    pub content_format: ContentFormat,
    pub sensitivity: Sensitivity,
    pub source_weight: f64,
    pub estimated_units: u64,
    pub citation_label: String,
}

impl Candidate {
    pub fn from_event(
        event: &ContextEvent,
        redactor: &SecretRedactor,
    ) -> Result<Self, EngineError> {
        let redacted = redactor.redact(&event.payload().model_text());
        let content = normalize_model_text(redacted.value());
        Ok(Self {
            record_type: ContextRecordType::ContextEvent,
            record_id: event.id().into(),
            occurred_at: event.occurred_at(),
            estimated_units: estimate_units(&content)?,
            content,
            content_format: ContentFormat::PlainText,
            sensitivity: event.sensitivity(),
            source_weight: source_weight(event),
            citation_label: format!("event:{}", event.id()),
        })
    }

    pub fn from_artifact(
        artifact: &SemanticArtifact,
        redactor: &SecretRedactor,
    ) -> Result<Self, EngineError> {
        let redacted = redactor.redact(artifact.content().text());
        let content = normalize_model_text(redacted.value());
        Ok(Self {
            record_type: ContextRecordType::SemanticArtifact,
            record_id: artifact.id().into(),
            occurred_at: artifact.created_at(),
            estimated_units: estimate_units(&content)?,
            content,
            content_format: ContentFormat::PlainText,
            sensitivity: artifact.sensitivity(),
            source_weight: 1.0,
            citation_label: format!("artifact:{}", artifact.id()),
        })
    }

    pub fn deduplication_key(&self) -> String {
        deduplication_key(&self.content)
    }
}

fn source_weight(event: &ContextEvent) -> f64 {
    use context_domain::ContextSource;

    match event.source() {
        ContextSource::Audio | ContextSource::Calendar => 0.9,
        ContextSource::GitHub | ContextSource::Notion => 0.85,
        ContextSource::Shell => 0.8,
        ContextSource::Browser => 0.6,
        ContextSource::External(_) => 0.5,
    }
}
