use std::collections::BTreeMap;

use context_domain::{
    ContextEvent, ContextSource, DayId, DomainError, EventId, EventKind, EventPayload, Provenance,
    RetentionPolicy, Sensitivity,
};
use time::macros::{date, datetime};

fn event(payload: EventPayload, retention: RetentionPolicy) -> Result<ContextEvent, DomainError> {
    ContextEvent::new(
        EventId::parse("018f6ea2-8f44-7f00-8000-000000000001")?,
        datetime!(2026-09-13 10:31:00 +09:00),
        DayId::new(date!(2026 - 09 - 13), "Asia/Tokyo")?,
        None,
        ContextSource::Shell,
        EventKind::Command,
        payload,
        BTreeMap::from([("redacted".to_owned(), "true".to_owned())]),
        Sensitivity::Sensitive,
        retention,
        Provenance {
            collector: "context-collector".to_owned(),
            device_id: "mac-local".to_owned(),
            captured_at: datetime!(2026-09-13 10:31:01 +09:00),
        },
    )
}

#[test]
fn rejects_empty_shell_command() {
    let result = event(
        EventPayload::ShellCommand {
            command: " ".to_owned(),
            cwd: "/workspace".to_owned(),
            exit_code: Some(1),
            duration_ms: Some(120),
        },
        RetentionPolicy::Days(30),
    );
    assert_eq!(
        result,
        Err(DomainError::EmptyField {
            field: "payload.command"
        })
    );
}

#[test]
fn rejects_zero_day_retention() {
    let result = event(
        EventPayload::ShellCommand {
            command: "cargo test".to_owned(),
            cwd: "/workspace".to_owned(),
            exit_code: Some(0),
            duration_ms: Some(1),
        },
        RetentionPolicy::Days(0),
    );
    assert_eq!(result, Err(DomainError::InvalidRetentionDays));
}

#[test]
fn rejects_invalid_json_instead_of_bypassing_constructor() {
    let invalid =
        include_str!("../../../../contracts/fixtures/invalid/context-event-zero-retention-v1.json");
    assert!(serde_json::from_str::<ContextEvent>(invalid).is_err());
}

#[test]
fn rejects_kind_payload_mismatch() {
    let invalid = include_str!(
        "../../../../contracts/fixtures/invalid/context-event-kind-payload-mismatch-v1.json"
    );
    let result = serde_json::from_str::<ContextEvent>(invalid);
    assert!(result.is_err_and(|error| error.to_string().contains("incompatible")));
}

#[test]
fn rejects_blank_timezone_during_deserialization() {
    let fixture = include_str!("../../../../contracts/fixtures/context-event-v1.json");
    let invalid = fixture.replace("Asia/Tokyo", " ");
    assert!(serde_json::from_str::<ContextEvent>(&invalid).is_err());
}

#[test]
fn round_trips_the_v1_fixture() -> Result<(), Box<dyn std::error::Error>> {
    let fixture = include_str!("../../../../contracts/fixtures/context-event-v1.json");
    let event: ContextEvent = serde_json::from_str(fixture)?;
    let actual = serde_json::to_value(event)?;
    let expected: serde_json::Value = serde_json::from_str(fixture)?;
    assert_eq!(actual, expected);
    Ok(())
}

#[test]
fn replaces_payload_without_mutating_original() -> Result<(), Box<dyn std::error::Error>> {
    let fixture = include_str!("../../../../contracts/fixtures/context-event-v1.json");
    let event: ContextEvent = serde_json::from_str(fixture)?;
    let payload = event
        .payload()
        .map_text(|value| value.replace("cargo", "swift"));
    let replaced = event.with_payload(payload)?;
    let original = serde_json::to_string(&event)?;
    let updated = serde_json::to_string(&replaced)?;
    assert!(original.contains("cargo test"));
    assert!(updated.contains("swift test"));
    Ok(())
}
