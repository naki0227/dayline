use context_domain::{ContextEvent, DayId, SemanticArtifact};
use context_store::{ContextStore, StoreError};
use time::macros::date;

const EVENT: &str = include_str!("../../../../contracts/fixtures/context-event-v1.json");
const ARTIFACT: &str = include_str!("../../../../contracts/fixtures/semantic-artifact-v1.json");

fn event_with_command(command: &str) -> Result<ContextEvent, Box<dyn std::error::Error>> {
    let mut value: serde_json::Value = serde_json::from_str(EVENT)?;
    value["payload"]["content"]["command"] = serde_json::json!(command);
    Ok(serde_json::from_value(value)?)
}

#[test]
fn redacts_before_event_persistence_and_rejects_duplicates()
-> Result<(), Box<dyn std::error::Error>> {
    let mut store = ContextStore::open_in_memory()?;
    let event = event_with_command("export API_KEY=top-secret")?;
    let sanitized = store.save_event(&event)?;
    assert!(!serde_json::to_string(&sanitized)?.contains("top-secret"));
    assert!(matches!(
        store.save_event(&event),
        Err(StoreError::DuplicateRecord { .. })
    ));

    let day = DayId::new(date!(2026 - 09 - 13), "Asia/Tokyo")?;
    let stored = store.events_for_day(&day)?;
    assert_eq!(stored.len(), 1);
    assert!(!serde_json::to_string(&stored)?.contains("top-secret"));
    Ok(())
}

#[test]
fn requires_evidence_before_artifact_persistence() -> Result<(), Box<dyn std::error::Error>> {
    let mut store = ContextStore::open_in_memory()?;
    let artifact: SemanticArtifact = serde_json::from_str(ARTIFACT)?;
    assert!(matches!(
        store.save_artifact(&artifact),
        Err(StoreError::MissingSourceEvent(_))
    ));
    Ok(())
}

#[test]
fn stores_artifact_after_its_evidence() -> Result<(), Box<dyn std::error::Error>> {
    let mut store = ContextStore::open_in_memory()?;
    let event: ContextEvent = serde_json::from_str(EVENT)?;
    let artifact: SemanticArtifact = serde_json::from_str(ARTIFACT)?;
    store.save_event(&event)?;
    store.save_artifact(&artifact)?;

    let day = DayId::new(date!(2026 - 09 - 13), "Asia/Tokyo")?;
    assert_eq!(store.artifacts_for_day(&day)?.len(), 1);
    Ok(())
}

#[test]
fn rejects_an_event_with_a_false_local_day() -> Result<(), Box<dyn std::error::Error>> {
    let mut store = ContextStore::open_in_memory()?;
    let mut value: serde_json::Value = serde_json::from_str(EVENT)?;
    value["day_id"]["local_date"] = serde_json::json!("2026-09-12");
    let event: ContextEvent = serde_json::from_value(value)?;
    assert!(matches!(
        store.save_event(&event),
        Err(StoreError::DayBoundary(_))
    ));
    Ok(())
}
