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
    value["budget"]["included_units"] = serde_json::json!(28);
    let result = serde_json::from_value::<ContextBundle>(value);
    assert!(result.is_err_and(|error| error.to_string().contains("duplicate identifiers")));
    Ok(())
}

#[test]
fn rejects_mismatched_item_unit_total() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    value["budget"]["included_units"] = serde_json::json!(13);
    let result = serde_json::from_value::<ContextBundle>(value);
    assert!(result.is_err_and(|error| error.to_string().contains("does not match")));
    Ok(())
}

#[test]
fn accepts_an_empty_context_bundle() -> Result<(), Box<dyn std::error::Error>> {
    let mut value = fixture_value()?;
    value["items"] = serde_json::json!([]);
    value["budget"]["included_units"] = serde_json::json!(0);
    let bundle = serde_json::from_value::<ContextBundle>(value)?;
    assert!(bundle.items().is_empty());
    Ok(())
}

#[test]
fn shrinks_in_ranked_order_and_records_omissions() -> Result<(), Box<dyn std::error::Error>> {
    let bundle: ContextBundle = serde_json::from_str(FIXTURE)?;
    let shrunk = bundle.shrink_to(1)?;
    let value = serde_json::to_value(shrunk)?;
    assert_eq!(value["items"].as_array().map(Vec::len), Some(0));
    assert_eq!(value["budget"]["maximum_units"], 1);
    assert_eq!(value["budget"]["included_units"], 0);
    assert_eq!(value["omissions"].as_array().map(Vec::len), Some(2));
    assert_eq!(value["omissions"][1]["reason"], "budget");
    Ok(())
}

#[test]
fn rejects_a_zero_shrink_budget() -> Result<(), Box<dyn std::error::Error>> {
    let bundle: ContextBundle = serde_json::from_str(FIXTURE)?;
    assert!(bundle.shrink_to(0).is_err());
    Ok(())
}
