use context_domain::ActionProposal;

const FIXTURE: &str = include_str!("../../../../contracts/fixtures/action-proposal-v1.json");

fn fixture_value() -> Result<serde_json::Value, serde_json::Error> {
    serde_json::from_str(FIXTURE)
}

#[test]
fn round_trips_the_v1_fixture() -> Result<(), Box<dyn std::error::Error>> {
    let proposal: ActionProposal = serde_json::from_str(FIXTURE)?;
    assert_eq!(serde_json::to_value(proposal)?, fixture_value()?);
    Ok(())
}

#[test]
fn rejects_destructive_action_without_confirmation() {
    let invalid = include_str!(
        "../../../../contracts/fixtures/invalid/action-proposal-destructive-without-confirmation-v1.json"
    );
    let result = serde_json::from_str::<ActionProposal>(invalid);
    assert!(result.is_err_and(|error| error.to_string().contains("explicit confirmation")));
}

#[test]
fn rejects_empty_evidence() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    value["source_artifact_ids"] = serde_json::json!([]);
    let result = serde_json::from_value::<ActionProposal>(value);
    assert!(result.is_err_and(|error| error.to_string().contains("at least one item")));
    Ok(())
}

#[test]
fn rejects_expiration_at_proposal_time() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    value["expires_at"] = value["proposed_at"].clone();
    let result = serde_json::from_value::<ActionProposal>(value);
    assert!(result.is_err_and(|error| error.to_string().contains("expiration")));
    Ok(())
}

#[test]
fn rejects_delete_not_marked_destructive() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    value["effect"] = serde_json::json!("delete");
    value["tool"]["operation"] = serde_json::json!("delete");
    value["risk"]["destructive"] = serde_json::json!(false);
    let result = serde_json::from_value::<ActionProposal>(value);
    assert!(result.is_err_and(|error| error.to_string().contains("marked destructive")));
    Ok(())
}

#[test]
fn rejects_unsupported_schema_version() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    value["schema_version"] = serde_json::json!(2);
    let result = serde_json::from_value::<ActionProposal>(value);
    assert!(result.is_err_and(|error| error.to_string().contains("unsupported schema version")));
    Ok(())
}
