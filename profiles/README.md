# Profiles

AI profiles describe product behavior: allowed sources, structured output,
language policy, update mode, and tool capability. Profiles cannot grant a
permission that the deterministic policy engine denies.

The canonical runtime resources live in
`packages/DaylineProductKit/Sources/DaylineProductKit/Resources/` so Swift Package
Manager includes them in every client:

- `daily-summary-v1.json`: One Day batch generation from audio, browser, terminal,
  and calendar context. Calendar is read-only; Notion is an explicit write
  destination.
- `live-meeting-v1.json`: session-scoped incremental generation every 30 seconds from
  live transcript and project/calendar context.

`DaylineProfileCatalog` validates IDs, versions, source lists, output sections,
update mode, interval invariants, and tool access before a profile reaches a use case.
Profile declarations can narrow capabilities but cannot bypass ActionProposal policy.
