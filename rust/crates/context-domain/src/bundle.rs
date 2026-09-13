use serde::{Deserialize, Serialize};
use time::OffsetDateTime;

use crate::validation::{require_text, require_unique};
use crate::{
    AssemblyProvenance, BundleId, ContextOmission, ContextTask, ContextWindow, DomainError,
    ProcessingLocation, RecordId, Sensitivity, SuggestedTool, VersionedIdentifier,
};

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ContextRecordType {
    ContextEvent,
    SemanticArtifact,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ContentFormat {
    PlainText,
    Json,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct ContextItem {
    record_type: ContextRecordType,
    record_id: RecordId,
    #[serde(with = "time::serde::rfc3339")]
    occurred_at: OffsetDateTime,
    content: String,
    content_format: ContentFormat,
    sensitivity: Sensitivity,
    relevance_score: f64,
    estimated_tokens: u64,
    citation_label: String,
}

impl ContextItem {
    /// Creates one ranked, model-ready context item.
    ///
    /// # Errors
    ///
    /// Returns a validation error for blank content, invalid score, or zero tokens.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        record_type: ContextRecordType,
        record_id: RecordId,
        occurred_at: OffsetDateTime,
        content: impl Into<String>,
        content_format: ContentFormat,
        sensitivity: Sensitivity,
        relevance_score: f64,
        estimated_tokens: u64,
        citation_label: impl Into<String>,
    ) -> Result<Self, DomainError> {
        let value = Self {
            record_type,
            record_id,
            occurred_at,
            content: content.into(),
            content_format,
            sensitivity,
            relevance_score,
            estimated_tokens,
            citation_label: citation_label.into(),
        };
        value.validate()?;
        Ok(value)
    }

    fn validate(&self) -> Result<(), DomainError> {
        require_text(&self.content, "items.content")?;
        require_text(&self.citation_label, "items.citation_label")?;
        if !self.relevance_score.is_finite() || !(0.0..=1.0).contains(&self.relevance_score) {
            return Err(DomainError::ValueOutOfRange {
                field: "items.relevance_score",
            });
        }
        if self.estimated_tokens == 0 {
            return Err(DomainError::ValueOutOfRange {
                field: "items.estimated_tokens",
            });
        }
        Ok(())
    }

    #[must_use]
    pub const fn record_id(&self) -> RecordId {
        self.record_id
    }

    #[must_use]
    pub const fn estimated_tokens(&self) -> u64 {
        self.estimated_tokens
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[allow(clippy::struct_field_names)] // Field names are fixed by the JSON contract.
pub struct TokenBudget {
    maximum_input_tokens: u64,
    included_input_tokens: u64,
    reserved_output_tokens: u64,
}

impl TokenBudget {
    /// Creates a token budget that fits within the model input limit.
    ///
    /// # Errors
    ///
    /// Returns an error for a zero maximum or an exceeded budget.
    pub fn new(
        maximum_input_tokens: u64,
        included_input_tokens: u64,
        reserved_output_tokens: u64,
    ) -> Result<Self, DomainError> {
        let value = Self {
            maximum_input_tokens,
            included_input_tokens,
            reserved_output_tokens,
        };
        value.validate()?;
        Ok(value)
    }

    fn validate(self) -> Result<(), DomainError> {
        if self.maximum_input_tokens == 0 {
            return Err(DomainError::ValueOutOfRange {
                field: "budget.maximum_input_tokens",
            });
        }
        let Some(total) = self
            .included_input_tokens
            .checked_add(self.reserved_output_tokens)
        else {
            return Err(DomainError::TokenBudgetExceeded);
        };
        if total > self.maximum_input_tokens {
            return Err(DomainError::TokenBudgetExceeded);
        }
        Ok(())
    }

    #[must_use]
    pub const fn included_input_tokens(self) -> u64 {
        self.included_input_tokens
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ContextProcessing {
    location: ProcessingLocation,
}

impl ContextProcessing {
    #[must_use]
    pub const fn new(location: ProcessingLocation) -> Self {
        Self { location }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(try_from = "RawContextBundle")]
pub struct ContextBundle {
    schema_version: u32,
    id: BundleId,
    #[serde(with = "time::serde::rfc3339")]
    built_at: OffsetDateTime,
    task: ContextTask,
    profile: VersionedIdentifier,
    window: ContextWindow,
    items: Vec<ContextItem>,
    budget: TokenBudget,
    processing: ContextProcessing,
    suggested_tools: Vec<SuggestedTool>,
    omissions: Vec<ContextOmission>,
    assembly: AssemblyProvenance,
}

impl ContextBundle {
    /// Creates a validated, policy-filtered model input bundle.
    ///
    /// # Errors
    ///
    /// Returns a validation error for invalid metadata, duplicate records, or a
    /// token count that does not match the included items.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: BundleId,
        built_at: OffsetDateTime,
        task: ContextTask,
        profile: VersionedIdentifier,
        window: ContextWindow,
        items: Vec<ContextItem>,
        budget: TokenBudget,
        processing: ContextProcessing,
        suggested_tools: Vec<SuggestedTool>,
        omissions: Vec<ContextOmission>,
        assembly: AssemblyProvenance,
    ) -> Result<Self, DomainError> {
        task.validate()?;
        profile.validate("profile.id", "profile.version")?;
        window.validate()?;
        budget.validate()?;
        for item in &items {
            item.validate()?;
        }
        let record_ids: Vec<_> = items.iter().map(ContextItem::record_id).collect();
        require_unique(&record_ids, "items.record_id")?;
        let included = items.iter().try_fold(0_u64, |total, item| {
            total
                .checked_add(item.estimated_tokens())
                .ok_or(DomainError::TokenBudgetExceeded)
        })?;
        if included != budget.included_input_tokens() {
            return Err(DomainError::TokenCountMismatch);
        }
        for tool in &suggested_tools {
            tool.validate()?;
        }
        for omission in &omissions {
            omission.validate()?;
        }
        assembly.validate()?;
        Ok(Self {
            schema_version: crate::CONTEXT_SCHEMA_VERSION,
            id,
            built_at,
            task,
            profile,
            window,
            items,
            budget,
            processing,
            suggested_tools,
            omissions,
            assembly,
        })
    }

    #[must_use]
    pub fn items(&self) -> &[ContextItem] {
        &self.items
    }
}

#[derive(Deserialize)]
struct RawContextBundle {
    schema_version: u32,
    id: BundleId,
    #[serde(with = "time::serde::rfc3339")]
    built_at: OffsetDateTime,
    task: ContextTask,
    profile: VersionedIdentifier,
    window: ContextWindow,
    items: Vec<ContextItem>,
    budget: TokenBudget,
    processing: ContextProcessing,
    suggested_tools: Vec<SuggestedTool>,
    omissions: Vec<ContextOmission>,
    assembly: AssemblyProvenance,
}

impl TryFrom<RawContextBundle> for ContextBundle {
    type Error = DomainError;

    fn try_from(raw: RawContextBundle) -> Result<Self, Self::Error> {
        if raw.schema_version != crate::CONTEXT_SCHEMA_VERSION {
            return Err(DomainError::UnsupportedSchemaVersion {
                expected: crate::CONTEXT_SCHEMA_VERSION,
                actual: raw.schema_version,
            });
        }
        Self::new(
            raw.id,
            raw.built_at,
            raw.task,
            raw.profile,
            raw.window,
            raw.items,
            raw.budget,
            raw.processing,
            raw.suggested_tools,
            raw.omissions,
            raw.assembly,
        )
    }
}
