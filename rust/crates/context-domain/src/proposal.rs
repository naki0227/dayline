use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use time::OffsetDateTime;

use crate::proposal_metadata::validate_arguments_schema;
use crate::validation::{require_non_empty, require_text, require_unique};
use crate::{
    ActionPermission, ActionProposer, ActionTarget, ArtifactId, DomainError, EventId, ProposalId,
    ProposedTool, RiskAssessment, Sensitivity, VersionedIdentifier,
};

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ProposalState {
    Proposed,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ActionEffect {
    Create,
    Update,
    Delete,
    Send,
    Publish,
    Schedule,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
#[serde(try_from = "RawActionProposal")]
pub struct ActionProposal {
    schema_version: u32,
    id: ProposalId,
    #[serde(with = "time::serde::rfc3339")]
    proposed_at: OffsetDateTime,
    #[serde(with = "time::serde::rfc3339::option")]
    expires_at: Option<OffsetDateTime>,
    state: ProposalState,
    source_artifact_ids: Vec<ArtifactId>,
    supporting_event_ids: Vec<EventId>,
    tool: ProposedTool,
    arguments_schema: VersionedIdentifier,
    arguments: BTreeMap<String, Value>,
    effect: ActionEffect,
    target: ActionTarget,
    risk: RiskAssessment,
    permission: ActionPermission,
    sensitivity: Sensitivity,
    idempotency_key: String,
    rationale: String,
    proposer: ActionProposer,
}

impl ActionProposal {
    /// Creates a validated, unexecuted external action proposal.
    ///
    /// # Errors
    ///
    /// Returns a typed validation error when evidence, tool metadata, risk,
    /// permission, expiry, or idempotency constraints are invalid.
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: ProposalId,
        proposed_at: OffsetDateTime,
        expires_at: Option<OffsetDateTime>,
        source_artifact_ids: Vec<ArtifactId>,
        supporting_event_ids: Vec<EventId>,
        tool: ProposedTool,
        arguments_schema: VersionedIdentifier,
        arguments: BTreeMap<String, Value>,
        effect: ActionEffect,
        target: ActionTarget,
        risk: RiskAssessment,
        permission: ActionPermission,
        sensitivity: Sensitivity,
        idempotency_key: impl Into<String>,
        rationale: impl Into<String>,
        proposer: ActionProposer,
    ) -> Result<Self, DomainError> {
        require_non_empty(&source_artifact_ids, "source_artifact_ids")?;
        require_unique(&source_artifact_ids, "source_artifact_ids")?;
        require_unique(&supporting_event_ids, "supporting_event_ids")?;
        if expires_at.is_some_and(|expires| expires <= proposed_at) {
            return Err(DomainError::InvalidExpiration);
        }
        tool.validate()?;
        validate_arguments_schema(&arguments_schema)?;
        target.validate()?;
        risk.validate()?;
        permission.validate()?;
        proposer.validate()?;
        if effect == ActionEffect::Delete && !risk.is_destructive() {
            return Err(DomainError::DeleteMustBeDestructive);
        }
        if risk.is_destructive()
            && permission.confirmation() != crate::ConfirmationRequirement::Required
        {
            return Err(DomainError::DestructiveConfirmationRequired);
        }
        let idempotency_key = idempotency_key.into();
        require_text(&idempotency_key, "idempotency_key")?;
        if idempotency_key.chars().count() > 200 {
            return Err(DomainError::StringTooLong {
                field: "idempotency_key",
                maximum: 200,
            });
        }
        let rationale = rationale.into();
        require_text(&rationale, "rationale")?;
        Ok(Self {
            schema_version: crate::CONTEXT_SCHEMA_VERSION,
            id,
            proposed_at,
            expires_at,
            state: ProposalState::Proposed,
            source_artifact_ids,
            supporting_event_ids,
            tool,
            arguments_schema,
            arguments,
            effect,
            target,
            risk,
            permission,
            sensitivity,
            idempotency_key,
            rationale,
            proposer,
        })
    }

    #[must_use]
    pub const fn effect(&self) -> ActionEffect {
        self.effect
    }

    #[must_use]
    pub const fn risk(&self) -> &RiskAssessment {
        &self.risk
    }

    #[must_use]
    pub const fn permission(&self) -> &ActionPermission {
        &self.permission
    }

    #[must_use]
    pub const fn tool(&self) -> &ProposedTool {
        &self.tool
    }
}

#[derive(Deserialize)]
struct RawActionProposal {
    schema_version: u32,
    id: ProposalId,
    #[serde(with = "time::serde::rfc3339")]
    proposed_at: OffsetDateTime,
    #[serde(with = "time::serde::rfc3339::option")]
    expires_at: Option<OffsetDateTime>,
    state: ProposalState,
    source_artifact_ids: Vec<ArtifactId>,
    supporting_event_ids: Vec<EventId>,
    tool: ProposedTool,
    arguments_schema: VersionedIdentifier,
    arguments: BTreeMap<String, Value>,
    effect: ActionEffect,
    target: ActionTarget,
    risk: RiskAssessment,
    permission: ActionPermission,
    sensitivity: Sensitivity,
    idempotency_key: String,
    rationale: String,
    proposer: ActionProposer,
}

impl TryFrom<RawActionProposal> for ActionProposal {
    type Error = DomainError;

    fn try_from(raw: RawActionProposal) -> Result<Self, Self::Error> {
        if raw.schema_version != crate::CONTEXT_SCHEMA_VERSION {
            return Err(DomainError::UnsupportedSchemaVersion {
                expected: crate::CONTEXT_SCHEMA_VERSION,
                actual: raw.schema_version,
            });
        }
        if raw.state != ProposalState::Proposed {
            return Err(DomainError::InvalidIdentifier { field: "state" });
        }
        Self::new(
            raw.id,
            raw.proposed_at,
            raw.expires_at,
            raw.source_artifact_ids,
            raw.supporting_event_ids,
            raw.tool,
            raw.arguments_schema,
            raw.arguments,
            raw.effect,
            raw.target,
            raw.risk,
            raw.permission,
            raw.sensitivity,
            raw.idempotency_key,
            raw.rationale,
            raw.proposer,
        )
    }
}
