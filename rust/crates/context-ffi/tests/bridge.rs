use context_ffi::{
    ContextBridgeError, build_context_bundle, build_stored_context_bundle,
    evaluate_action_proposal, persist_context_event, persist_semantic_artifact,
    shrink_context_bundle,
};

const REQUEST: &str = include_str!("../../../../fixtures/vertical-slice-request-v1.json");
const STORE_REQUEST: &str =
    include_str!("../../../../fixtures/vertical-slice-store-request-v1.json");
const EVENT: &str = include_str!("../../../../contracts/fixtures/context-event-v1.json");
const ARTIFACT: &str = include_str!("../../../../contracts/fixtures/semantic-artifact-v1.json");
const PROPOSAL: &str = include_str!("../../../../contracts/fixtures/action-proposal-v1.json");

#[test]
fn validates_and_requires_confirmation_for_external_output()
-> Result<(), Box<dyn std::error::Error>> {
    let response = evaluate_action_proposal(PROPOSAL.to_owned())?;
    let value: serde_json::Value = serde_json::from_str(&response)?;
    assert_eq!(value["decision"], "ask");
    assert_eq!(value["reason"], "proposal_requires_confirmation");
    Ok(())
}

#[test]
fn rejects_invalid_action_proposal_without_leaking_arguments() {
    let invalid = PROPOSAL.replace("\"schema_version\": 1", "\"schema_version\": 2");
    assert!(matches!(
        evaluate_action_proposal(invalid),
        Err(ContextBridgeError::InvalidRequest)
    ));
}

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

#[test]
fn builds_context_from_the_rust_owned_store() -> Result<(), Box<dyn std::error::Error>> {
    let directory = tempfile::tempdir()?;
    let database = directory.path().join("stored-context.sqlite");
    let path = database.to_string_lossy().into_owned();
    persist_context_event(path.clone(), EVENT.to_owned())?;

    let bundle_json = build_stored_context_bundle(path, STORE_REQUEST.to_owned())?;
    let bundle: serde_json::Value = serde_json::from_str(&bundle_json)?;

    assert_eq!(bundle["items"].as_array().map(Vec::len), Some(1));
    assert_eq!(bundle["items"][0]["record_type"], "context_event");
    Ok(())
}
