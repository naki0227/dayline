use serde::{Deserialize, Serialize};
use time::OffsetDateTime;

use crate::validation::{require_text, require_unique};
use crate::{
    AssemblyProvenance, BundleId, ContextOmission, ContextTask, ContextWindow, DomainError,
    OmissionReason, ProcessingLocation, RecordId, Sensitivity, SuggestedTool, VersionedIdentifier,
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
    estimated_units: u64,
    citation_label: String,
}

impl ContextItem {
    /// Creates one ranked, model-ready context item.
    ///
    /// # Errors
    ///
    /// Returns a validation error for blank content, invalid score, or zero units.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        record_type: ContextRecordType,
        record_id: RecordId,
        occurred_at: OffsetDateTime,
        content: impl Into<String>,
        content_format: ContentFormat,
        sensitivity: Sensitivity,
        relevance_score: f64,
        estimated_units: u64,
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
            estimated_units,
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
        if self.estimated_units == 0 {
            return Err(DomainError::ValueOutOfRange {
                field: "items.estimated_units",
            });
        }
        Ok(())
    }

    #[must_use]
    pub const fn record_id(&self) -> RecordId {
        self.record_id
    }

    #[must_use]
    pub const fn estimated_units(&self) -> u64 {
        self.estimated_units
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum BudgetUnit {
    QuarterCharacterEstimate,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[allow(clippy::struct_field_names)] // Field names are fixed by the JSON contract.
pub struct ContextBudget {
    unit: BudgetUnit,
    maximum_units: u64,
    included_units: u64,
}

impl ContextBudget {
    /// Creates an abstract estimate budget for deterministic shrinking.
    ///
    /// # Errors
    ///
    /// Returns an error for a zero maximum or usage above the estimate limit.
    pub fn new(maximum_units: u64, included_units: u64) -> Result<Self, DomainError> {
        let value = Self {
            unit: BudgetUnit::QuarterCharacterEstimate,
            maximum_units,
            included_units,
        };
        value.validate()?;
        Ok(value)
    }

    fn validate(self) -> Result<(), DomainError> {
        if self.maximum_units == 0 {
            return Err(DomainError::ValueOutOfRange {
                field: "budget.maximum_units",
            });
        }
        if self.included_units > self.maximum_units {
            return Err(DomainError::ContextBudgetExceeded);
        }
        Ok(())
    }

    #[must_use]
    pub const fn included_units(self) -> u64 {
        self.included_units
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
    budget: ContextBudget,
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
    /// unit count that does not match the included items.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: BundleId,
        built_at: OffsetDateTime,
        task: ContextTask,
        profile: VersionedIdentifier,
        window: ContextWindow,
        items: Vec<ContextItem>,
        budget: ContextBudget,
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
                .checked_add(item.estimated_units())
                .ok_or(DomainError::ContextBudgetExceeded)
        })?;
        if included != budget.included_units() {
            return Err(DomainError::UnitCountMismatch);
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

    /// Returns the same ranked bundle constrained to a smaller abstract budget.
    ///
    /// Item order is preserved, making repeated model-runtime retries deterministic.
    ///
    /// # Errors
    ///
    /// Returns an error for a zero budget or if omission accounting overflows.
    pub fn shrink_to(&self, maximum_units: u64) -> Result<Self, DomainError> {
        let mut included_units = 0_u64;
        let mut omitted_count = 0_u64;
        let mut items = Vec::new();
        for item in &self.items {
            let next = included_units.checked_add(item.estimated_units());
            if next.is_some_and(|units| units <= maximum_units) {
                included_units = next.ok_or(DomainError::ContextBudgetExceeded)?;
                items.push(item.clone());
            } else {
                omitted_count = omitted_count
                    .checked_add(1)
                    .ok_or(DomainError::ContextBudgetExceeded)?;
            }
        }

        let mut omissions = self.omissions.clone();
        if omitted_count > 0 {
            omissions.push(ContextOmission::new(OmissionReason::Budget, omitted_count)?);
        }
        Self::new(
            self.id,
            self.built_at,
            self.task.clone(),
            self.profile.clone(),
            self.window.clone(),
            items,
            ContextBudget::new(maximum_units, included_units)?,
            self.processing,
            self.suggested_tools.clone(),
            omissions,
            self.assembly.clone(),
        )
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
    budget: ContextBudget,
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
