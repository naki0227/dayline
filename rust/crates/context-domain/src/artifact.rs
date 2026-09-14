use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use time::OffsetDateTime;

use crate::validation::{require_text, require_unique};
use crate::{
    ArtifactId, DayId, DomainError, EventId, RetentionPolicy, RunId, Sensitivity, SessionId,
};

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ArtifactKind {
    Summary,
    Decision,
    ActionItem,
    Idea,
    Question,
    Topic,
    Entity,
    External,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct SemanticContent {
    text: String,
    attributes: BTreeMap<String, String>,
}

impl SemanticContent {
    /// Creates validated model-derived content.
    ///
    /// # Errors
    ///
    /// Returns [`DomainError::EmptyField`] when `text` is blank.
    pub fn new(
        text: impl Into<String>,
        attributes: BTreeMap<String, String>,
    ) -> Result<Self, DomainError> {
        let text = text.into();
        require_text(&text, "content.text")?;
        Ok(Self { text, attributes })
    }

    fn validate(&self) -> Result<(), DomainError> {
        require_text(&self.text, "content.text")
    }

    #[must_use]
    pub fn text(&self) -> &str {
        &self.text
    }

    #[must_use]
    pub fn map_text(&self, transform: impl FnOnce(&str) -> String) -> Self {
        Self {
            text: transform(&self.text),
            attributes: self.attributes.clone(),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct GenerationProvenance {
    runtime: String,
    model: String,
    prompt_id: String,
    prompt_version: u32,
    run_id: RunId,
    #[serde(with = "time::serde::rfc3339")]
    generated_at: OffsetDateTime,
}

impl GenerationProvenance {
    /// Creates validated generation provenance.
    ///
    /// # Errors
    ///
    /// Returns a typed validation error for blank names or a zero prompt version.
    pub fn new(
        runtime: impl Into<String>,
        model: impl Into<String>,
        prompt_id: impl Into<String>,
        prompt_version: u32,
        run_id: RunId,
        generated_at: OffsetDateTime,
    ) -> Result<Self, DomainError> {
        let value = Self {
            runtime: runtime.into(),
            model: model.into(),
            prompt_id: prompt_id.into(),
            prompt_version,
            run_id,
            generated_at,
        };
        value.validate()?;
        Ok(value)
    }

    fn validate(&self) -> Result<(), DomainError> {
        require_text(&self.runtime, "generation.runtime")?;
        require_text(&self.model, "generation.model")?;
        require_text(&self.prompt_id, "generation.prompt_id")?;
        if self.prompt_version == 0 {
            return Err(DomainError::InvalidVersion {
                field: "generation.prompt_version",
            });
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(try_from = "RawSemanticArtifact")]
pub struct SemanticArtifact {
    schema_version: u32,
    id: ArtifactId,
    #[serde(with = "time::serde::rfc3339")]
    created_at: OffsetDateTime,
    day_id: DayId,
    session_id: Option<SessionId>,
    kind: ArtifactKind,
    content: SemanticContent,
    source_event_ids: Vec<EventId>,
    source_artifact_ids: Vec<ArtifactId>,
    confidence: Option<f64>,
    sensitivity: Sensitivity,
    retention: RetentionPolicy,
    generation: GenerationProvenance,
}

impl SemanticArtifact {
    /// Creates a validated semantic artifact traceable to observed events.
    ///
    /// # Errors
    ///
    /// Returns a typed validation error when evidence, confidence, retention, or
    /// generation provenance is invalid.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: ArtifactId,
        created_at: OffsetDateTime,
        day_id: DayId,
        session_id: Option<SessionId>,
        kind: ArtifactKind,
        content: SemanticContent,
        source_event_ids: Vec<EventId>,
        source_artifact_ids: Vec<ArtifactId>,
        confidence: Option<f64>,
        sensitivity: Sensitivity,
        retention: RetentionPolicy,
        generation: GenerationProvenance,
    ) -> Result<Self, DomainError> {
        content.validate()?;
        if source_event_ids.is_empty() && source_artifact_ids.is_empty() {
            return Err(DomainError::MissingSource);
        }
        require_unique(&source_event_ids, "source_event_ids")?;
        require_unique(&source_artifact_ids, "source_artifact_ids")?;
        if source_artifact_ids.contains(&id) {
            return Err(DomainError::ArtifactSelfReference);
        }
        if confidence.is_some_and(|value| !value.is_finite() || !(0.0..=1.0).contains(&value)) {
            return Err(DomainError::InvalidConfidence);
        }
        retention.validate()?;
        generation.validate()?;
        Ok(Self {
            schema_version: crate::CONTEXT_SCHEMA_VERSION,
            id,
            created_at,
            day_id,
            session_id,
            kind,
            content,
            source_event_ids,
            source_artifact_ids,
            confidence,
            sensitivity,
            retention,
            generation,
        })
    }

    #[must_use]
    pub const fn id(&self) -> ArtifactId {
        self.id
    }

    #[must_use]
    pub const fn created_at(&self) -> OffsetDateTime {
        self.created_at
    }

    #[must_use]
    pub const fn day_id(&self) -> &DayId {
        &self.day_id
    }

    #[must_use]
    pub const fn session_id(&self) -> Option<SessionId> {
        self.session_id
    }

    #[must_use]
    pub const fn content(&self) -> &SemanticContent {
        &self.content
    }

    #[must_use]
    pub const fn sensitivity(&self) -> Sensitivity {
        self.sensitivity
    }

    /// Copies the artifact with newly validated semantic content.
    ///
    /// # Errors
    ///
    /// Returns an error when the replacement content violates an invariant.
    pub fn with_content(&self, content: SemanticContent) -> Result<Self, DomainError> {
        Self::new(
            self.id,
            self.created_at,
            self.day_id.clone(),
            self.session_id,
            self.kind,
            content,
            self.source_event_ids.clone(),
            self.source_artifact_ids.clone(),
            self.confidence,
            self.sensitivity,
            self.retention,
            self.generation.clone(),
        )
    }
}

#[derive(Deserialize)]
struct RawSemanticArtifact {
    schema_version: u32,
    id: ArtifactId,
    #[serde(with = "time::serde::rfc3339")]
    created_at: OffsetDateTime,
    day_id: DayId,
    session_id: Option<SessionId>,
    kind: ArtifactKind,
    content: SemanticContent,
    source_event_ids: Vec<EventId>,
    source_artifact_ids: Vec<ArtifactId>,
    confidence: Option<f64>,
    sensitivity: Sensitivity,
    retention: RetentionPolicy,
    generation: GenerationProvenance,
}

impl TryFrom<RawSemanticArtifact> for SemanticArtifact {
    type Error = DomainError;

    fn try_from(raw: RawSemanticArtifact) -> Result<Self, Self::Error> {
        if raw.schema_version != crate::CONTEXT_SCHEMA_VERSION {
            return Err(DomainError::UnsupportedSchemaVersion {
                expected: crate::CONTEXT_SCHEMA_VERSION,
                actual: raw.schema_version,
            });
        }
        Self::new(
            raw.id,
            raw.created_at,
            raw.day_id,
            raw.session_id,
            raw.kind,
            raw.content,
            raw.source_event_ids,
            raw.source_artifact_ids,
            raw.confidence,
            raw.sensitivity,
            raw.retention,
            raw.generation,
        )
    }
}
