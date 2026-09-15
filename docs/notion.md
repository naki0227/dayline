# Notion output

## Setup

1. Create an internal Notion integration with Insert Content capability.
2. Share the destination parent page with that integration.
3. In Dayline, generate a Daily summary and choose **Notionへ出力**.
4. Enter the integration token and parent page ID, inspect the destination shown in
   the confirmation prompt, then explicitly approve the write.

The token is stored in the local device Keychain. The parent page ID is treated as
non-secret app configuration. Neither belongs in source code, `.env`, GitHub Variables,
logs, model prompts, or screenshots.

## Execution boundary

`DaylineProductKit` converts only the selected SemanticArtifact into Markdown and a v1
ActionProposal. Rust policy must permit or request confirmation. `NotionKit` validates
the proposal again, reads the token only at execution time, and calls Notion's Create a
page API with pinned `Notion-Version: 2026-03-11`.

Raw audio, full transcripts, browser and shell observations, SQLite paths, and Apple
signing identifiers are excluded. A failed export does not modify or remove local
context. CI uses a fake transport and never contacts a real Notion workspace.

## Troubleshooting

- A permission failure usually means the integration lacks Insert Content capability
  or the parent page was not shared with it.
- An invalid-parent failure means the configured ID is empty or the page is unavailable
  to the integration.
- Re-entering a token replaces the Keychain item; it is not printed back into the UI.
