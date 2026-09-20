# Notion output

## Product setup

Dayline's product flow is **Notionと連携**:

1. The app requests an opaque OAuth session from the configured HTTPS broker.
2. `ASWebAuthenticationSession` opens Notion so the user can choose a workspace and
   share the pages Dayline may access.
3. The broker validates OAuth state and exchanges the authorization code. The app
   callback contains only an opaque session ID, never a Notion token.
4. Dayline stores the returned connection in the device-only Keychain, displays the
   workspace name, and lists only pages available to that connection.
5. The user chooses a parent page, reviews the existing confirmation prompt, and
   explicitly approves the write.

The production build setting `DAYLINE_NOTION_OAUTH_BROKER_URL` must be an HTTPS base
URL implementing [`notion-oauth-broker.md`](notion-oauth-broker.md). The implementation
lives in [`services/notion-oauth-broker`](../services/notion-oauth-broker/README.md) and
has independent CI/tag CD. A registered Notion public connection, Cloudflare credentials,
and deployed broker remain operator prerequisites for the live device acceptance test.

## Credential lifecycle

The versioned Keychain record contains the access/refresh token pair, bot and workspace
IDs, display metadata, an opaque connection ID, and a separate revocation capability.
It uses `AfterFirstUnlockThisDeviceOnly` and is never synchronized. Disconnect asks the
broker to revoke remotely and removes the local OAuth and legacy items even when remote
revocation cannot be confirmed.

Existing development installations with the old `access-token` Keychain item remain
readable and can continue to use a manually configured parent page ID. The normal UI no
longer asks new users to paste a token. Saving an OAuth connection removes the legacy
item.

## Execution boundary

OAuth grants credentials but never grants autonomous writes. `DaylineProductKit`
converts only the selected SemanticArtifact into Markdown and a v1 ActionProposal. Rust
policy evaluates it before presentation and again before execution. `NotionKit`
validates the proposal, reads the access token only at execution time, and calls Create
Page with pinned `Notion-Version: 2026-03-11` only after explicit confirmation.

Raw audio, full transcripts, browser/shell observations, SQLite paths, OAuth secrets,
and Apple signing identifiers are excluded. Integration failures use finite,
content-free categories; upstream response bodies are ignored. CI uses fake transports
and never contacts a real Notion workspace.

## Troubleshooting

- **OAuthがまだ構成されていません**: set a valid HTTPS broker URL in the build
  configuration and verify the broker/public Notion connection setup.
- No destinations: share at least one writable page during Notion authorization, then
  choose **ページを再読み込み**.
- Authorization failure: reconnect so Notion can rotate credentials and permissions.
- Disconnect warning: local credentials were deleted, but the broker could not confirm
  remote revocation; inspect content-free broker metrics using the connection ID only.
