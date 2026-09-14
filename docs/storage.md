# Local storage

`context-store` owns detailed device-local persistence. Its write order is fixed:

1. Resolve and validate `day_id` using its IANA timezone.
2. Redact secrets from every textual payload/content field.
3. Re-run domain validation through immutable replacement constructors.
4. Verify evidence exists and artifact provenance is acyclic.
5. Commit the record and normalized evidence edges in SQLite.

Duplicate IDs are errors; records are never overwritten. The SQLite database file
must not be placed in iCloud Drive or synchronized as a file.

## Migration v1

The forward migration is
`rust/crates/context-store/migrations/0001_context_records.up.sql`. It creates
strict Event and Artifact document tables, day indexes, and foreign-key evidence
tables. The migration is idempotent and is applied when `ContextStore` opens.

## Rollback

`rust/crates/context-store/migrations/0001_context_records.down.sql` is the explicit
rollback. It drops all v1 context tables and therefore deletes local context data.
Before applying it, stop all Dayline writers and copy the database to an explicit
backup path. Recovery after rollback requires restoring that backup; there is no
in-place reconstruction of raw context.
