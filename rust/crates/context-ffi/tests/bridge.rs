use context_ffi::{
    ContextBridgeError, build_context_bundle, persist_context_event, persist_semantic_artifact,
    shrink_context_bundle,
};

const REQUEST: &str = include_str!("../../../../fixtures/vertical-slice-request-v1.json");
const EVENT: &str = include_str!("../../../../contracts/fixtures/context-event-v1.json");
const ARTIFACT: &str = include_str!("../../../../contracts/fixtures/semantic-artifact-v1.json");

#[test]
fn builds_a_context_bundle_over_the_public_boundary() -> Result<(), Box<dyn std::error::Error>> {
    let bundle = build_context_bundle(REQUEST.to_owned())?;
    let value: serde_json::Value = serde_json::from_str(&bundle)?;
    assert_eq!(value["schema_version"], 1);
    assert_eq!(value["items"].as_array().map(Vec::len), Some(1));
    assert_eq!(value["budget"]["unit"], "quarter_character_estimate");
    Ok(())
}

#[test]
fn rejects_an_unknown_request_version_without_details() {
    let request = REQUEST.replace("\"request_version\": 1", "\"request_version\": 2");
    assert!(matches!(
        build_context_bundle(request),
        Err(ContextBridgeError::InvalidRequest)
    ));
}

#[test]
fn shrinks_a_bundle_over_the_public_boundary() -> Result<(), Box<dyn std::error::Error>> {
    let bundle = build_context_bundle(REQUEST.to_owned())?;
    let shrunk = shrink_context_bundle(bundle, 1)?;
    let value: serde_json::Value = serde_json::from_str(&shrunk)?;
    assert_eq!(value["items"].as_array().map(Vec::len), Some(0));
    assert_eq!(value["budget"]["maximum_units"], 1);
    Ok(())
}

#[test]
fn persists_the_event_then_generated_artifact() -> Result<(), Box<dyn std::error::Error>> {
    let directory = tempfile::tempdir()?;
    let database = directory.path().join("dayline.sqlite");
    let path = database.to_string_lossy().into_owned();
    persist_context_event(path.clone(), EVENT.to_owned())?;
    let saved = persist_semantic_artifact(path, ARTIFACT.to_owned())?;
    let value: serde_json::Value = serde_json::from_str(&saved)?;
    assert_eq!(value["kind"], "summary");
    assert_eq!(value["source_event_ids"].as_array().map(Vec::len), Some(1));
    Ok(())
}
