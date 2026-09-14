use std::collections::BTreeMap;

use context_domain::{
    ArtifactId, ArtifactKind, DayId, DomainError, EventId, GenerationProvenance, RetentionPolicy,
    RunId, SemanticArtifact, SemanticContent, Sensitivity,
};
use time::macros::{date, datetime};

fn event_id() -> Result<EventId, DomainError> {
    EventId::parse("018f6ea2-8f44-7f00-8000-000000000001")
}

fn artifact(
    source_ids: Vec<EventId>,
    confidence: Option<f64>,
) -> Result<SemanticArtifact, DomainError> {
    SemanticArtifact::new(
        ArtifactId::parse("018f6ea2-8f44-7f00-8000-000000000101")?,
        datetime!(2026-09-13 10:32:00 +09:00),
        DayId::new(date!(2026 - 09 - 13), "Asia/Tokyo")?,
        None,
        ArtifactKind::Summary,
        SemanticContent::new("A summary", BTreeMap::new())?,
        source_ids,
        confidence,
        Sensitivity::Sensitive,
        RetentionPolicy::Days(30),
        GenerationProvenance::new(
            "apple_intelligence",
            "system-language-model",
            "daily-summary",
            1,
            RunId::parse("018f6ea2-8f44-7f00-8000-000000000201")?,
            datetime!(2026-09-13 10:32:00 +09:00),
        )?,
    )
}

#[test]
fn rejects_missing_or_duplicate_sources() -> Result<(), DomainError> {
    assert_eq!(
        artifact(Vec::new(), Some(0.5)),
        Err(DomainError::EmptyCollection {
            field: "source_event_ids"
        })
    );
    let id = event_id()?;
    assert_eq!(
        artifact(vec![id, id], Some(0.5)),
        Err(DomainError::DuplicateIdentifier {
            field: "source_event_ids"
        })
    );
    Ok(())
}

#[test]
fn rejects_non_finite_or_out_of_range_confidence() -> Result<(), DomainError> {
    assert_eq!(
        artifact(vec![event_id()?], Some(f64::NAN)),
        Err(DomainError::InvalidConfidence)
    );
    assert_eq!(
        artifact(vec![event_id()?], Some(1.1)),
        Err(DomainError::InvalidConfidence)
    );
    Ok(())
}

#[test]
fn rejects_invalid_json_instead_of_bypassing_constructor() {
    let invalid = include_str!(
        "../../../../contracts/fixtures/invalid/semantic-artifact-empty-sources-v1.json"
    );
    assert!(serde_json::from_str::<SemanticArtifact>(invalid).is_err());
}

#[test]
fn round_trips_the_v1_fixture() -> Result<(), Box<dyn std::error::Error>> {
    let fixture = include_str!("../../../../contracts/fixtures/semantic-artifact-v1.json");
    let artifact: SemanticArtifact = serde_json::from_str(fixture)?;
    let actual = serde_json::to_value(artifact)?;
    let expected: serde_json::Value = serde_json::from_str(fixture)?;
    assert_eq!(actual, expected);
    Ok(())
}

#[test]
fn replaces_content_without_mutating_original() -> Result<(), Box<dyn std::error::Error>> {
    let fixture = include_str!("../../../../contracts/fixtures/semantic-artifact-v1.json");
    let artifact: SemanticArtifact = serde_json::from_str(fixture)?;
    let content = artifact
        .content()
        .map_text(|_| "Redacted summary".to_owned());
    let replaced = artifact.with_content(content)?;
    assert!(serde_json::to_string(&artifact)?.contains("ContextEvent contract"));
    assert!(serde_json::to_string(&replaced)?.contains("Redacted summary"));
    Ok(())
}
