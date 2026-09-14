DROP TABLE IF EXISTS artifact_artifact_sources;
DROP TABLE IF EXISTS artifact_event_sources;
DROP TABLE IF EXISTS semantic_artifacts;
DROP TABLE IF EXISTS context_events;
DELETE FROM schema_migrations WHERE version = 1;
DROP TABLE IF EXISTS schema_migrations;
