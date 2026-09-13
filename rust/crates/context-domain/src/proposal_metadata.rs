use serde::{Deserialize, Serialize};

use crate::validation::{require_identifier, require_non_empty, require_text, require_unique};
use crate::{DomainError, RunId, VersionedIdentifier};

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ProposedTool {
    integration: String,
    name: String,
    operation: String,
}

impl ProposedTool {
    /// Creates a reference to a registered tool operation.
    ///
    /// # Errors
    ///
    /// Returns an error when any registry identifier is invalid.
    pub fn new(
        integration: impl Into<String>,
        name: impl Into<String>,
        operation: impl Into<String>,
    ) -> Result<Self, DomainError> {
        let value = Self {
            integration: integration.into(),
            name: name.into(),
            operation: operation.into(),
        };
        value.validate()?;
        Ok(value)
    }

    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        require_identifier(&self.integration, "tool.integration")?;
        require_identifier(&self.name, "tool.name")?;
        require_identifier(&self.operation, "tool.operation")
    }

    #[must_use]
    pub fn integration(&self) -> &str {
        &self.integration
    }

    #[must_use]
    pub fn operation(&self) -> &str {
        &self.operation
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ActionTarget {
    #[serde(rename = "type")]
    kind: String,
    identifier: String,
    display_name: Option<String>,
}

impl ActionTarget {
    /// Creates a non-secret external target reference.
    ///
    /// # Errors
    ///
    /// Returns an error for an invalid target type or blank identifier.
    pub fn new(
        kind: impl Into<String>,
        identifier: impl Into<String>,
        display_name: Option<String>,
    ) -> Result<Self, DomainError> {
        let value = Self {
            kind: kind.into(),
            identifier: identifier.into(),
            display_name,
        };
        value.validate()?;
        Ok(value)
    }

    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        require_identifier(&self.kind, "target.type")?;
        require_text(&self.identifier, "target.identifier")
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum RiskLevel {
    Low,
    Medium,
    High,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct RiskAssessment {
    level: RiskLevel,
    destructive: bool,
    reasons: Vec<String>,
}

impl RiskAssessment {
    /// Creates a risk classification for deterministic policy evaluation.
    ///
    /// # Errors
    ///
    /// Returns an error for blank or duplicate reasons.
    pub fn new(
        level: RiskLevel,
        destructive: bool,
        reasons: Vec<String>,
    ) -> Result<Self, DomainError> {
        let value = Self {
            level,
            destructive,
            reasons,
        };
        value.validate()?;
        Ok(value)
    }

    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        for reason in &self.reasons {
            require_text(reason, "risk.reasons")?;
        }
        require_unique(&self.reasons, "risk.reasons")
    }

    #[must_use]
    pub const fn is_destructive(&self) -> bool {
        self.destructive
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ConfirmationRequirement {
    Required,
    PolicyDecides,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ActionPermission {
    required_scopes: Vec<String>,
    confirmation: ConfirmationRequirement,
}

impl ActionPermission {
    /// Creates the scopes and confirmation mode required before execution.
    ///
    /// # Errors
    ///
    /// Returns an error for missing, duplicate, or invalid scopes.
    pub fn new(
        required_scopes: Vec<String>,
        confirmation: ConfirmationRequirement,
    ) -> Result<Self, DomainError> {
        let value = Self {
            required_scopes,
            confirmation,
        };
        value.validate()?;
        Ok(value)
    }

    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        require_non_empty(&self.required_scopes, "permission.required_scopes")?;
        require_unique(&self.required_scopes, "permission.required_scopes")?;
        for scope in &self.required_scopes {
            require_identifier(scope, "permission.required_scopes")?;
        }
        Ok(())
    }

    #[must_use]
    pub const fn confirmation(&self) -> ConfirmationRequirement {
        self.confirmation
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case", tag = "type")]
pub enum ActionProposer {
    Model {
        runtime: String,
        model: String,
        prompt_id: String,
        prompt_version: u32,
        run_id: RunId,
    },
    Rule {
        rule_id: String,
        rule_version: u32,
    },
}

impl ActionProposer {
    pub(crate) fn validate(&self) -> Result<(), DomainError> {
        match self {
            Self::Model {
                runtime,
                model,
                prompt_id,
                prompt_version,
                ..
            } => {
                require_text(runtime, "proposer.runtime")?;
                require_text(model, "proposer.model")?;
                require_identifier(prompt_id, "proposer.prompt_id")?;
                require_version(*prompt_version, "proposer.prompt_version")
            }
            Self::Rule {
                rule_id,
                rule_version,
            } => {
                require_identifier(rule_id, "proposer.rule_id")?;
                require_version(*rule_version, "proposer.rule_version")
            }
        }
    }
}

pub(crate) fn validate_arguments_schema(value: &VersionedIdentifier) -> Result<(), DomainError> {
    value.validate("arguments_schema.id", "arguments_schema.version")
}

fn require_version(value: u32, field: &'static str) -> Result<(), DomainError> {
    if value == 0 {
        return Err(DomainError::InvalidVersion { field });
    }
    Ok(())
}
