use serde::{Deserialize, Serialize};
use time::OffsetDateTime;

use crate::DomainError;
use crate::validation::{require_identifier, require_text};

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ContextTask {
    id: String,
    objective: String,
}

impl ContextTask {
    /// Creates a task describing why context is being assembled.
    ///
    /// # Errors
    ///
    /// Returns a validation error for an invalid ID or blank objective.
    pub fn new(id: impl Into<String>, objective: impl Into<String>) -> Result<Self, DomainError> {
        let value = Self {
            id: id.into(),
            objective: objective.into(),
        };
        value.validate()?;
        Ok(value)
    }

    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        require_identifier(&self.id, "task.id")?;
        require_text(&self.objective, "task.objective")
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct VersionedIdentifier {
    id: String,
    version: u32,
}

impl VersionedIdentifier {
    /// Creates a validated contract identifier and version.
    ///
    /// # Errors
    ///
    /// Returns a validation error for an invalid ID or zero version.
    pub fn new(id: impl Into<String>, version: u32) -> Result<Self, DomainError> {
        let value = Self {
            id: id.into(),
            version,
        };
        value.validate("versioned_identifier.id", "versioned_identifier.version")?;
        Ok(value)
    }

    pub(crate) fn validate(
        &self,
        id_field: &'static str,
        version_field: &'static str,
    ) -> Result<(), DomainError> {
        require_identifier(&self.id, id_field)?;
        if self.version == 0 {
            return Err(DomainError::InvalidVersion {
                field: version_field,
            });
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ContextWindow {
    #[serde(with = "time::serde::rfc3339")]
    start: OffsetDateTime,
    #[serde(with = "time::serde::rfc3339")]
    end: OffsetDateTime,
    timezone: String,
}

impl ContextWindow {
    /// Creates a non-empty context time window.
    ///
    /// # Errors
    ///
    /// Returns an error for a blank timezone or a non-increasing range.
    pub fn new(
        start: OffsetDateTime,
        end: OffsetDateTime,
        timezone: impl Into<String>,
    ) -> Result<Self, DomainError> {
        let value = Self {
            start,
            end,
            timezone: timezone.into(),
        };
        value.validate()?;
        Ok(value)
    }

    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        require_text(&self.timezone, "window.timezone")?;
        if self.end <= self.start {
            return Err(DomainError::InvalidTimeWindow);
        }
        Ok(())
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ProcessingLocation {
    OnDeviceOnly,
    ExternalAllowed,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolAccess {
    Read,
    Write,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct SuggestedTool {
    name: String,
    access: ToolAccess,
    reason: String,
}

impl SuggestedTool {
    /// Creates a tool suggestion without granting execution permission.
    ///
    /// # Errors
    ///
    /// Returns a validation error for an invalid name or blank reason.
    pub fn new(
        name: impl Into<String>,
        access: ToolAccess,
        reason: impl Into<String>,
    ) -> Result<Self, DomainError> {
        let value = Self {
            name: name.into(),
            access,
            reason: reason.into(),
        };
        value.validate()?;
        Ok(value)
    }

    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        require_identifier(&self.name, "suggested_tools.name")?;
        require_text(&self.reason, "suggested_tools.reason")
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum OmissionReason {
    Budget,
    Policy,
    Permission,
    Deduplicated,
    Unsupported,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ContextOmission {
    reason: OmissionReason,
    count: u64,
}

impl ContextOmission {
    /// Creates an aggregate reason for omitted records.
    ///
    /// # Errors
    ///
    /// Returns an error when count is zero.
    pub fn new(reason: OmissionReason, count: u64) -> Result<Self, DomainError> {
        if count == 0 {
            return Err(DomainError::ValueOutOfRange {
                field: "omissions.count",
            });
        }
        Ok(Self { reason, count })
    }

    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        if self.count == 0 {
            return Err(DomainError::ValueOutOfRange {
                field: "omissions.count",
            });
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct AssemblyProvenance {
    engine: String,
    engine_version: String,
    policy_version: u32,
    ranking_version: u32,
}

impl AssemblyProvenance {
    /// Creates validated assembly provenance.
    ///
    /// # Errors
    ///
    /// Returns a validation error for blank names or zero policy versions.
    pub fn new(
        engine: impl Into<String>,
        engine_version: impl Into<String>,
        policy_version: u32,
        ranking_version: u32,
    ) -> Result<Self, DomainError> {
        let value = Self {
            engine: engine.into(),
            engine_version: engine_version.into(),
            policy_version,
            ranking_version,
        };
        value.validate()?;
        Ok(value)
    }

    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        require_text(&self.engine, "assembly.engine")?;
        require_text(&self.engine_version, "assembly.engine_version")?;
        if self.policy_version == 0 {
            return Err(DomainError::InvalidVersion {
                field: "assembly.policy_version",
            });
        }
        if self.ranking_version == 0 {
            return Err(DomainError::InvalidVersion {
                field: "assembly.ranking_version",
            });
        }
        Ok(())
    }
}
