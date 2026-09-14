use context_domain::{
    AssemblyProvenance, BundleId, ContextEvent, ContextProcessing, ContextSource, ContextTask,
    SemanticArtifact, Sensitivity, SessionId, SuggestedTool, VersionedIdentifier,
};
use context_engine::BundlePlan;
use context_query::{ContextQuery, QueryError};
use serde::Deserialize;
use time::OffsetDateTime;

use crate::ContextBridgeError;

#[derive(Deserialize)]
pub(crate) struct BuildContextRequest {
    request_version: u32,
    plan: PlanRequest,
    query: QueryRequest,
    events: Vec<ContextEvent>,
    artifacts: Vec<SemanticArtifact>,
}

impl BuildContextRequest {
    pub fn into_parts(
        self,
    ) -> Result<
        (
            BundlePlan,
            ContextQuery,
            Vec<ContextEvent>,
            Vec<SemanticArtifact>,
        ),
        ContextBridgeError,
    > {
        if self.request_version != 1 {
            return Err(ContextBridgeError::InvalidRequest);
        }
        Ok((
            self.plan.into_plan(),
            self.query
                .into_query()
                .map_err(|_| ContextBridgeError::InvalidRequest)?,
            self.events,
            self.artifacts,
        ))
    }
}

#[derive(Deserialize)]
struct PlanRequest {
    id: BundleId,
    #[serde(with = "time::serde::rfc3339")]
    built_at: OffsetDateTime,
    task: ContextTask,
    profile: VersionedIdentifier,
    timezone: String,
    processing: ContextProcessing,
    #[serde(default)]
    suggested_tools: Vec<SuggestedTool>,
    assembly: AssemblyProvenance,
}

impl PlanRequest {
    fn into_plan(self) -> BundlePlan {
        BundlePlan {
            id: self.id,
            built_at: self.built_at,
            task: self.task,
            profile: self.profile,
            timezone: self.timezone,
            processing: self.processing,
            suggested_tools: self.suggested_tools,
            assembly: self.assembly,
        }
    }
}

#[derive(Deserialize)]
struct QueryRequest {
    #[serde(with = "time::serde::rfc3339")]
    start: OffsetDateTime,
    #[serde(with = "time::serde::rfc3339")]
    end: OffsetDateTime,
    #[serde(default)]
    sources: Vec<ContextSource>,
    session_id: Option<SessionId>,
    project_hint: Option<String>,
    maximum_sensitivity: Sensitivity,
    maximum_context_units: u64,
}

impl QueryRequest {
    fn into_query(self) -> Result<ContextQuery, QueryError> {
        ContextQuery::new(
            self.start,
            self.end,
            self.sources,
            self.session_id,
            self.project_hint,
            self.maximum_sensitivity,
            self.maximum_context_units,
        )
    }
}
