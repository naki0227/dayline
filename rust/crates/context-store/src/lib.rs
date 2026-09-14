#![doc = "`SQLite` persistence with mandatory redaction and provenance checks."]

mod error;

use std::path::Path;

use context_domain::{ContextEvent, DayId, SemanticArtifact};
use context_redact::SecretRedactor;
use context_time::{validate_artifact_day, validate_event_day};
pub use error::StoreError;
use rusqlite::{Connection, OptionalExtension, Transaction, params};

const MIGRATION_V1: &str = include_str!("../migrations/0001_context_records.up.sql");

pub struct ContextStore {
    connection: Connection,
    redactor: SecretRedactor,
}

impl ContextStore {
    /// Opens or creates a local `SQLite` database and applies pending migrations.
    ///
    /// # Errors
    ///
    /// Returns an error when `SQLite` cannot open/migrate or redaction cannot initialize.
    pub fn open(path: impl AsRef<Path>) -> Result<Self, StoreError> {
        Self::from_connection(Connection::open(path)?)
    }

    /// Opens an isolated in-memory database, primarily for deterministic tests.
    ///
    /// # Errors
    ///
    /// Returns an error when migration or redaction initialization fails.
    pub fn open_in_memory() -> Result<Self, StoreError> {
        Self::from_connection(Connection::open_in_memory()?)
    }

    fn from_connection(connection: Connection) -> Result<Self, StoreError> {
        connection.execute_batch(MIGRATION_V1)?;
        Ok(Self {
            connection,
            redactor: SecretRedactor::new()?,
        })
    }

    /// Persists an immutable observed event after day validation and redaction.
    ///
    /// # Errors
    ///
    /// Returns a typed error for invalid day data, duplicate IDs, serialization,
    /// or `SQLite` failures.
    pub fn save_event(&mut self, event: &ContextEvent) -> Result<ContextEvent, StoreError> {
        validate_event_day(event)?;
        let sanitized = event.with_payload(
            event
                .payload()
                .map_text(|text| self.redactor.redact(text).value().to_owned()),
        )?;
        let id = sanitized.id().to_string();
        if record_exists(&self.connection, "context_events", &id)? {
            return Err(StoreError::DuplicateRecord {
                record_type: "ContextEvent",
                id,
            });
        }
        self.connection.execute(
            "INSERT INTO context_events \
             (id, occurred_at_unix, day_local_date, day_timezone, document) \
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                id,
                sanitized.occurred_at().unix_timestamp(),
                sanitized.day_id().local_date().to_string(),
                sanitized.day_id().timezone(),
                serde_json::to_string(&sanitized)?,
            ],
        )?;
        Ok(sanitized)
    }

    /// Persists generated meaning and normalized provenance in one transaction.
    ///
    /// # Errors
    ///
    /// Returns a typed error for invalid days, missing evidence, duplicate IDs,
    /// provenance cycles, serialization, or `SQLite` failures.
    pub fn save_artifact(
        &mut self,
        artifact: &SemanticArtifact,
    ) -> Result<SemanticArtifact, StoreError> {
        validate_artifact_day(artifact)?;
        let sanitized = artifact.with_content(
            artifact
                .content()
                .map_text(|text| self.redactor.redact(text).value().to_owned()),
        )?;
        let document = serde_json::to_string(&sanitized)?;
        let transaction = self.connection.transaction()?;
        ensure_artifact_sources(&transaction, &sanitized)?;
        let id = sanitized.id().to_string();
        if record_exists(&transaction, "semantic_artifacts", &id)? {
            return Err(StoreError::DuplicateRecord {
                record_type: "SemanticArtifact",
                id,
            });
        }
        transaction.execute(
            "INSERT INTO semantic_artifacts \
             (id, created_at_unix, day_local_date, day_timezone, document) \
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                id,
                sanitized.created_at().unix_timestamp(),
                sanitized.day_id().local_date().to_string(),
                sanitized.day_id().timezone(),
                document,
            ],
        )?;
        insert_artifact_sources(&transaction, &sanitized)?;
        ensure_acyclic(&transaction)?;
        transaction.commit()?;
        Ok(sanitized)
    }

    /// Loads validated events for one local calendar day in chronological order.
    ///
    /// # Errors
    ///
    /// Returns an error when `SQLite` fails or a stored document is invalid.
    pub fn events_for_day(&self, day: &DayId) -> Result<Vec<ContextEvent>, StoreError> {
        load_for_day(&self.connection, "context_events", "occurred_at_unix", day)
    }

    /// Loads validated semantic artifacts for one local day in chronological order.
    ///
    /// # Errors
    ///
    /// Returns an error when `SQLite` fails or a stored document is invalid.
    pub fn artifacts_for_day(&self, day: &DayId) -> Result<Vec<SemanticArtifact>, StoreError> {
        load_for_day(
            &self.connection,
            "semantic_artifacts",
            "created_at_unix",
            day,
        )
    }
}

fn record_exists(connection: &Connection, table: &str, id: &str) -> Result<bool, StoreError> {
    let sql = format!("SELECT 1 FROM {table} WHERE id = ?1");
    Ok(connection
        .query_row(&sql, [id], |_| Ok(()))
        .optional()?
        .is_some())
}

fn ensure_artifact_sources(
    transaction: &Transaction<'_>,
    artifact: &SemanticArtifact,
) -> Result<(), StoreError> {
    for id in artifact.source_event_ids() {
        if !record_exists(transaction, "context_events", &id.to_string())? {
            return Err(StoreError::MissingSourceEvent(id.to_string()));
        }
    }
    for id in artifact.source_artifact_ids() {
        if !record_exists(transaction, "semantic_artifacts", &id.to_string())? {
            return Err(StoreError::MissingSourceArtifact(id.to_string()));
        }
    }
    Ok(())
}

fn insert_artifact_sources(
    transaction: &Transaction<'_>,
    artifact: &SemanticArtifact,
) -> Result<(), StoreError> {
    let artifact_id = artifact.id().to_string();
    for event_id in artifact.source_event_ids() {
        transaction.execute(
            "INSERT INTO artifact_event_sources (artifact_id, event_id) VALUES (?1, ?2)",
            params![artifact_id, event_id.to_string()],
        )?;
    }
    for source_id in artifact.source_artifact_ids() {
        transaction.execute(
            "INSERT INTO artifact_artifact_sources \
             (artifact_id, source_artifact_id) VALUES (?1, ?2)",
            params![artifact_id, source_id.to_string()],
        )?;
    }
    Ok(())
}

fn ensure_acyclic(connection: &Connection) -> Result<(), StoreError> {
    let cycle: Option<i64> = connection
        .query_row(
            "WITH RECURSIVE paths(current, path, cycle) AS (\
               SELECT source_artifact_id, ',' || artifact_id || ',' || source_artifact_id || ',', 0 \
               FROM artifact_artifact_sources \
               UNION ALL \
               SELECT edge.source_artifact_id, \
                      paths.path || edge.source_artifact_id || ',', \
                      instr(paths.path, ',' || edge.source_artifact_id || ',') > 0 \
               FROM paths \
               JOIN artifact_artifact_sources edge ON edge.artifact_id = paths.current \
               WHERE paths.cycle = 0\
             ) SELECT 1 FROM paths WHERE cycle = 1 LIMIT 1",
            [],
            |row| row.get(0),
        )
        .optional()?;
    if cycle.is_some() {
        return Err(StoreError::ArtifactCycle);
    }
    Ok(())
}

fn load_for_day<T: serde::de::DeserializeOwned>(
    connection: &Connection,
    table: &str,
    order_column: &str,
    day: &DayId,
) -> Result<Vec<T>, StoreError> {
    let sql = format!(
        "SELECT document FROM {table} \
         WHERE day_local_date = ?1 AND day_timezone = ?2 \
         ORDER BY {order_column}, id"
    );
    let mut statement = connection.prepare(&sql)?;
    let documents = statement.query_map(
        params![day.local_date().to_string(), day.timezone()],
        |row| row.get::<_, String>(0),
    )?;
    documents
        .map(|document| Ok(serde_json::from_str(&document?)?))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::{ContextStore, MIGRATION_V1, StoreError, ensure_acyclic};

    #[test]
    fn migration_is_idempotent() -> Result<(), Box<dyn std::error::Error>> {
        let store = ContextStore::open_in_memory()?;
        store.connection.execute_batch(MIGRATION_V1)?;
        Ok(())
    }

    #[test]
    fn detects_a_corrupt_provenance_cycle() -> Result<(), Box<dyn std::error::Error>> {
        let store = ContextStore::open_in_memory()?;
        store.connection.execute_batch(
            "INSERT INTO semantic_artifacts VALUES \
             ('a', 0, '2026-09-13', 'Asia/Tokyo', '{}');
             INSERT INTO semantic_artifacts VALUES \
             ('b', 0, '2026-09-13', 'Asia/Tokyo', '{}');
             INSERT INTO artifact_artifact_sources VALUES ('a', 'b');
             INSERT INTO artifact_artifact_sources VALUES ('b', 'a');",
        )?;
        assert!(matches!(
            ensure_acyclic(&store.connection),
            Err(StoreError::ArtifactCycle)
        ));
        Ok(())
    }
}
