PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
) STRICT;

CREATE TABLE IF NOT EXISTS context_events (
    id TEXT PRIMARY KEY,
    occurred_at_unix INTEGER NOT NULL,
    day_local_date TEXT NOT NULL,
    day_timezone TEXT NOT NULL,
    document TEXT NOT NULL
) STRICT;

CREATE INDEX IF NOT EXISTS context_events_day_idx
    ON context_events(day_local_date, day_timezone, occurred_at_unix);

CREATE TABLE IF NOT EXISTS semantic_artifacts (
    id TEXT PRIMARY KEY,
    created_at_unix INTEGER NOT NULL,
    day_local_date TEXT NOT NULL,
    day_timezone TEXT NOT NULL,
    document TEXT NOT NULL
) STRICT;

CREATE INDEX IF NOT EXISTS semantic_artifacts_day_idx
    ON semantic_artifacts(day_local_date, day_timezone, created_at_unix);

CREATE TABLE IF NOT EXISTS artifact_event_sources (
    artifact_id TEXT NOT NULL REFERENCES semantic_artifacts(id) ON DELETE CASCADE,
    event_id TEXT NOT NULL REFERENCES context_events(id) ON DELETE RESTRICT,
    PRIMARY KEY (artifact_id, event_id)
) STRICT;

CREATE TABLE IF NOT EXISTS artifact_artifact_sources (
    artifact_id TEXT NOT NULL REFERENCES semantic_artifacts(id) ON DELETE CASCADE,
    source_artifact_id TEXT NOT NULL REFERENCES semantic_artifacts(id) ON DELETE RESTRICT,
    PRIMARY KEY (artifact_id, source_artifact_id),
    CHECK (artifact_id <> source_artifact_id)
) STRICT;

INSERT OR IGNORE INTO schema_migrations(version) VALUES (1);
