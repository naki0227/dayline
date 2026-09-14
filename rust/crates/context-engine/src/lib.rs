#![doc = "Context filtering, redaction, deduplication, ranking, and assembly."]

mod candidate;

use std::collections::HashSet;

use candidate::Candidate;
use context_domain::{
    AssemblyProvenance, BundleId, ContextBundle, ContextEvent, ContextItem, ContextOmission,
    ContextProcessing, ContextTask, ContextWindow, DomainError, OmissionReason, SemanticArtifact,
    SuggestedTool, TokenBudget, VersionedIdentifier,
};
use context_query::ContextQuery;
use context_ranking::{RankingCandidate, RelevanceRanker};
use context_redact::{RedactionError, SecretRedactor};
use thiserror::Error;
use time::OffsetDateTime;

#[derive(Debug, Error)]
pub enum EngineError {
    #[error(transparent)]
    Domain(#[from] DomainError),

    #[error(transparent)]
    Redaction(#[from] RedactionError),

    #[error("context content is too large to measure")]
    ContentTooLarge,
}

pub struct BundlePlan {
    pub id: BundleId,
    pub built_at: OffsetDateTime,
    pub task: ContextTask,
    pub profile: VersionedIdentifier,
    pub timezone: String,
    pub processing: ContextProcessing,
    pub suggested_tools: Vec<SuggestedTool>,
    pub assembly: AssemblyProvenance,
}

pub struct ContextEngine {
    redactor: SecretRedactor,
}

impl ContextEngine {
    /// Creates an engine with the built-in pre-persistence redaction policy.
    ///
    /// # Errors
    ///
    /// Returns an error if a built-in redaction pattern cannot compile.
    pub fn new() -> Result<Self, EngineError> {
        Ok(Self {
            redactor: SecretRedactor::new()?,
        })
    }

    /// Builds deterministic model-ready context without invoking a model.
    ///
    /// # Errors
    ///
    /// Returns an error if content measurement or a resulting domain invariant fails.
    pub fn build(
        &self,
        plan: BundlePlan,
        query: &ContextQuery,
        events: &[ContextEvent],
        artifacts: &[SemanticArtifact],
    ) -> Result<ContextBundle, EngineError> {
        let mut candidates = self.candidates(query, events, artifacts)?;
        candidates.sort_by(|left, right| {
            right
                .occurred_at
                .cmp(&left.occurred_at)
                .then_with(|| left.record_id.cmp(&right.record_id))
        });
        let mut deduplication_keys = HashSet::new();
        let before_deduplication = candidates.len();
        candidates.retain(|candidate| deduplication_keys.insert(candidate.deduplication_key()));
        let deduplicated = before_deduplication - candidates.len();

        let ranker = RelevanceRanker::new(plan.built_at, query.project_hint());
        let mut scored_candidates: Vec<_> = candidates
            .into_iter()
            .map(|candidate| {
                let score = ranker.score(&RankingCandidate {
                    text: &candidate.content,
                    occurred_at: candidate.occurred_at,
                    source_weight: candidate.source_weight,
                });
                (candidate, score)
            })
            .collect();
        scored_candidates.sort_by(|(left, left_score), (right, right_score)| {
            right_score
                .total_cmp(left_score)
                .then_with(|| right.occurred_at.cmp(&left.occurred_at))
                .then_with(|| left.record_id.cmp(&right.record_id))
        });

        let available = query.maximum_input_tokens() - query.reserved_output_tokens();
        let mut used = 0_u64;
        let mut budget_omissions = 0_u64;
        let mut items = Vec::new();
        for (candidate, score) in scored_candidates {
            let Some(next_used) = used.checked_add(candidate.estimated_tokens) else {
                budget_omissions += 1;
                continue;
            };
            if next_used > available {
                budget_omissions += 1;
                continue;
            }
            used = next_used;
            items.push(ContextItem::new(
                candidate.record_type,
                candidate.record_id,
                candidate.occurred_at,
                candidate.content,
                candidate.content_format,
                candidate.sensitivity,
                score,
                candidate.estimated_tokens,
                candidate.citation_label,
            )?);
        }
        let mut omissions = Vec::new();
        if deduplicated > 0 {
            omissions.push(ContextOmission::new(
                OmissionReason::Deduplicated,
                u64::try_from(deduplicated).map_err(|_| EngineError::ContentTooLarge)?,
            )?);
        }
        if budget_omissions > 0 {
            omissions.push(ContextOmission::new(
                OmissionReason::Budget,
                budget_omissions,
            )?);
        }
        ContextBundle::new(
            plan.id,
            plan.built_at,
            plan.task,
            plan.profile,
            ContextWindow::new(query.start(), query.end(), plan.timezone)?,
            items,
            TokenBudget::new(
                query.maximum_input_tokens(),
                used,
                query.reserved_output_tokens(),
            )?,
            plan.processing,
            plan.suggested_tools,
            omissions,
            plan.assembly,
        )
        .map_err(EngineError::from)
    }

    fn candidates(
        &self,
        query: &ContextQuery,
        events: &[ContextEvent],
        artifacts: &[SemanticArtifact],
    ) -> Result<Vec<Candidate>, EngineError> {
        let event_candidates = events
            .iter()
            .filter(|event| query.matches_event(event))
            .map(|event| Candidate::from_event(event, &self.redactor));
        let artifact_candidates = artifacts
            .iter()
            .filter(|artifact| query.matches_artifact(artifact))
            .map(|artifact| Candidate::from_artifact(artifact, &self.redactor));
        event_candidates.chain(artifact_candidates).collect()
    }
}
