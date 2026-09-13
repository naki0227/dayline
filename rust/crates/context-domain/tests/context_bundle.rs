use context_domain::ContextBundle;

const FIXTURE: &str = include_str!("../../../../contracts/fixtures/context-bundle-v1.json");

fn fixture_value() -> Result<serde_json::Value, serde_json::Error> {
    serde_json::from_str(FIXTURE)
}

#[test]
fn round_trips_the_v1_fixture() -> Result<(), Box<dyn std::error::Error>> {
    let bundle: ContextBundle = serde_json::from_str(FIXTURE)?;
    assert_eq!(serde_json::to_value(bundle)?, fixture_value()?);
    Ok(())
}

#[test]
fn rejects_schema_invalid_zero_budget() {
    let invalid =
        include_str!("../../../../contracts/fixtures/invalid/context-bundle-zero-budget-v1.json");
    assert!(serde_json::from_str::<ContextBundle>(invalid).is_err());
}

#[test]
fn rejects_non_increasing_time_window() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    value["window"]["end"] = value["window"]["start"].clone();
    let result = serde_json::from_value::<ContextBundle>(value);
    assert!(result.is_err_and(|error| error.to_string().contains("time window")));
    Ok(())
}

#[test]
fn rejects_duplicate_record_ids() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    let first = value["items"][0].clone();
    value["items"]
        .as_array_mut()
        .ok_or("items must be an array")?
        .push(first);
    value["budget"]["included_input_tokens"] = serde_json::json!(28);
    let result = serde_json::from_value::<ContextBundle>(value);
    assert!(result.is_err_and(|error| error.to_string().contains("duplicate identifiers")));
    Ok(())
}

#[test]
fn rejects_mismatched_item_token_total() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    value["budget"]["included_input_tokens"] = serde_json::json!(13);
    let result = serde_json::from_value::<ContextBundle>(value);
    assert!(result.is_err_and(|error| error.to_string().contains("does not match")));
    Ok(())
}

#[test]
fn accepts_an_empty_context_bundle() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    value["items"] = serde_json::json!([]);
    value["budget"]["included_input_tokens"] = serde_json::json!(0);
    let bundle = serde_json::from_value::<ContextBundle>(value)?;
    assert!(bundle.items().is_empty());
    Ok(())
}
