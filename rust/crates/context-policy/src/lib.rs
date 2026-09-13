#![doc = "Deterministic permission policy for proposed external actions."]

use context_domain::{ActionProposal, ConfirmationRequirement};
use thiserror::Error;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PermissionDecision {
    Allow,
    Ask,
    Deny,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DecisionReason {
    MatchingRule,
    ProposalRequiresConfirmation,
    DestructiveWithoutRule,
    DestructiveRequiresConfirmation,
    NoMatchingRule,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct PolicyEvaluation {
    pub decision: PermissionDecision,
    pub reason: DecisionReason,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ToolPolicy {
    integration: String,
    operation: String,
    decision: PermissionDecision,
}

impl ToolPolicy {
    /// Creates an exact integration-operation policy rule.
    ///
    /// # Errors
    ///
    /// Returns [`PolicyError::InvalidRule`] for blank selectors.
    pub fn new(
        integration: impl Into<String>,
        operation: impl Into<String>,
        decision: PermissionDecision,
    ) -> Result<Self, PolicyError> {
        let value = Self {
            integration: integration.into(),
            operation: operation.into(),
            decision,
        };
        if value.integration.trim().is_empty() || value.operation.trim().is_empty() {
            return Err(PolicyError::InvalidRule);
        }
        Ok(value)
    }

    fn matches(&self, proposal: &ActionProposal) -> bool {
        self.integration == proposal.tool().integration()
            && self.operation == proposal.tool().operation()
    }
}

#[derive(Debug, Error, Eq, PartialEq)]
pub enum PolicyError {
    #[error("policy integration and operation must not be blank")]
    InvalidRule,
}

#[derive(Default)]
pub struct PolicyEngine {
    rules: Vec<ToolPolicy>,
}

impl PolicyEngine {
    #[must_use]
    pub fn new(rules: Vec<ToolPolicy>) -> Self {
        Self { rules }
    }

    #[must_use]
    pub fn evaluate(&self, proposal: &ActionProposal) -> PolicyEvaluation {
        let rule = self.rules.iter().find(|rule| rule.matches(proposal));
        if proposal.risk().is_destructive() {
            return match rule.map(|rule| rule.decision) {
                None | Some(PermissionDecision::Deny) => PolicyEvaluation {
                    decision: PermissionDecision::Deny,
                    reason: DecisionReason::DestructiveWithoutRule,
                },
                Some(PermissionDecision::Allow | PermissionDecision::Ask) => PolicyEvaluation {
                    decision: PermissionDecision::Ask,
                    reason: DecisionReason::DestructiveRequiresConfirmation,
                },
            };
        }
        if let Some(rule) = rule
            && rule.decision == PermissionDecision::Deny
        {
            return PolicyEvaluation {
                decision: PermissionDecision::Deny,
                reason: DecisionReason::MatchingRule,
            };
        }
        if proposal.permission().confirmation() == ConfirmationRequirement::Required {
            return PolicyEvaluation {
                decision: PermissionDecision::Ask,
                reason: DecisionReason::ProposalRequiresConfirmation,
            };
        }
        rule.map_or(
            PolicyEvaluation {
                decision: PermissionDecision::Ask,
                reason: DecisionReason::NoMatchingRule,
            },
            |rule| PolicyEvaluation {
                decision: rule.decision,
                reason: DecisionReason::MatchingRule,
            },
        )
    }
}

#[cfg(test)]
mod tests {
    use context_domain::ActionProposal;

    use super::{DecisionReason, PermissionDecision, PolicyEngine, ToolPolicy};

    const FIXTURE: &str = include_str!("../../../../contracts/fixtures/action-proposal-v1.json");

    fn proposal_with(
        destructive: bool,
        confirmation: &str,
    ) -> Result<ActionProposal, Box<dyn std::error::Error>> {
        let mut value: serde_json::Value = serde_json::from_str(FIXTURE)?;
        value["risk"]["destructive"] = serde_json::json!(destructive);
        value["permission"]["confirmation"] = serde_json::json!(confirmation);
        Ok(serde_json::from_value(value)?)
    }

    #[test]
    fn defaults_external_writes_to_ask() -> Result<(), Box<dyn std::error::Error>> {
        let proposal = proposal_with(false, "policy_decides")?;
        let result = PolicyEngine::default().evaluate(&proposal);
        assert_eq!(result.decision, PermissionDecision::Ask);
        assert_eq!(result.reason, DecisionReason::NoMatchingRule);
        Ok(())
    }

    #[test]
    fn explicit_allow_rule_allows_non_destructive_action() -> Result<(), Box<dyn std::error::Error>>
    {
        let proposal = proposal_with(false, "policy_decides")?;
        let policy = ToolPolicy::new("notion", "create", PermissionDecision::Allow)?;
        let result = PolicyEngine::new(vec![policy]).evaluate(&proposal);
        assert_eq!(result.decision, PermissionDecision::Allow);
        Ok(())
    }

    #[test]
    fn proposal_confirmation_overrides_allow_rule() -> Result<(), Box<dyn std::error::Error>> {
        let proposal: ActionProposal = serde_json::from_str(FIXTURE)?;
        let policy = ToolPolicy::new("notion", "create", PermissionDecision::Allow)?;
        let result = PolicyEngine::new(vec![policy]).evaluate(&proposal);
        assert_eq!(result.decision, PermissionDecision::Ask);
        assert_eq!(result.reason, DecisionReason::ProposalRequiresConfirmation);
        Ok(())
    }

    #[test]
    fn destructive_action_without_rule_is_denied() -> Result<(), Box<dyn std::error::Error>> {
        let mut value: serde_json::Value = serde_json::from_str(FIXTURE)?;
        value["risk"]["destructive"] = serde_json::json!(true);
        let proposal: ActionProposal = serde_json::from_value(value)?;
        let result = PolicyEngine::default().evaluate(&proposal);
        assert_eq!(result.decision, PermissionDecision::Deny);
        assert_eq!(result.reason, DecisionReason::DestructiveWithoutRule);
        Ok(())
    }

    #[test]
    fn destructive_allow_rule_still_requires_confirmation() -> Result<(), Box<dyn std::error::Error>>
    {
        let mut value: serde_json::Value = serde_json::from_str(FIXTURE)?;
        value["risk"]["destructive"] = serde_json::json!(true);
        let proposal: ActionProposal = serde_json::from_value(value)?;
        let policy = ToolPolicy::new("notion", "create", PermissionDecision::Allow)?;
        let result = PolicyEngine::new(vec![policy]).evaluate(&proposal);
        assert_eq!(result.decision, PermissionDecision::Ask);
        assert_eq!(
            result.reason,
            DecisionReason::DestructiveRequiresConfirmation
        );
        Ok(())
    }
}
