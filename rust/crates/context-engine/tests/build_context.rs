use context_domain::{
    AssemblyProvenance, BundleId, ContextEvent, ContextProcessing, ContextTask, ProcessingLocation,
    SemanticArtifact, Sensitivity, VersionedIdentifier,
};
use context_engine::{BundlePlan, ContextEngine};
use context_query::ContextQuery;
use time::macros::datetime;

const EVENT: &str = include_str!("../../../../contracts/fixtures/context-event-v1.json");
const ARTIFACT: &str = include_str!("../../../../contracts/fixtures/semantic-artifact-v1.json");

fn plan() -> Result<BundlePlan, Box<dyn std::error::Error>> {
    Ok(BundlePlan {
        id: BundleId::parse("018f6ea2-8f44-7f00-8000-000000000301")?,
        built_at: datetime!(2026-09-13 12:00:00 +09:00),
        task: ContextTask::new("daily_summary", "Summarize today's work")?,
        profile: VersionedIdentifier::new("daily_summary", 1)?,
        timezone: "Asia/Tokyo".to_owned(),
        processing: ContextProcessing::new(ProcessingLocation::OnDeviceOnly),
        suggested_tools: Vec::new(),
        assembly: AssemblyProvenance::new("context-core", "0.1.0", 1, 1)?,
    })
}

fn query(maximum: u64) -> Result<ContextQuery, Box<dyn std::error::Error>> {
    Ok(ContextQuery::new(
        datetime!(2026-09-13 00:00:00 +09:00),
        datetime!(2026-09-14 00:00:00 +09:00),
        Vec::new(),
        None,
        Some("context".to_owned()),
        Sensitivity::Sensitive,
        maximum,
    )?)
}

fn event_with_secret(id: &str, command: &str) -> Result<ContextEvent, Box<dyn std::error::Error>> {
    let mut value: serde_json::Value = serde_json::from_str(EVENT)?;
    value["id"] = serde_json::json!(id);
    value["payload"]["content"]["command"] = serde_json::json!(command);
    Ok(serde_json::from_value(value)?)
}

#[test]
fn redacts_and_deduplicates_before_assembly() -> Result<(), Box<dyn std::error::Error>> {
    let first = event_with_secret(
        "018f6ea2-8f44-7f00-8000-000000000001",
        "export API_KEY=top-secret",
    )?;
    let duplicate = event_with_secret(
        "018f6ea2-8f44-7f00-8000-000000000002",
        "export API_KEY=top-secret",
    )?;
    let artifact: SemanticArtifact = serde_json::from_str(ARTIFACT)?;
    let bundle =
        ContextEngine::new()?.build(plan()?, &query(4096)?, &[first, duplicate], &[artifact])?;
    let value = serde_json::to_value(bundle)?;
    let encoded = serde_json::to_string(&value)?;
    assert!(!encoded.contains("top-secret"));
    assert!(encoded.contains("API_KEY=***"));
    assert_eq!(value["items"].as_array().map(Vec::len), Some(2));
    assert_eq!(value["omissions"][0]["reason"], "deduplicated");
    assert_eq!(value["omissions"][0]["count"], 1);
    Ok(())
}

#[test]
fn omits_oversized_candidates_without_failing_bundle() -> Result<(), Box<dyn std::error::Error>> {
    let event: ContextEvent = serde_json::from_str(EVENT)?;
    let bundle = ContextEngine::new()?.build(plan()?, &query(10)?, &[event], &[])?;
    let value = serde_json::to_value(bundle)?;
    assert_eq!(value["items"].as_array().map(Vec::len), Some(0));
    assert_eq!(value["omissions"][0]["reason"], "budget");
    assert_eq!(value["omissions"][0]["count"], 1);
    Ok(())
}
