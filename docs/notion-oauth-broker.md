# Notion OAuth broker contract

The broker is the only component allowed to know `NOTION_CLIENT_SECRET`. All endpoints
must use HTTPS in production, reject oversized bodies, rate-limit by session/IP, avoid
logging request bodies, and return content-free errors.

## Start a session

`POST /v1/notion/oauth/sessions`

```json
{
  "callback_url": "dayline://oauth/notion"
}
```

```json
{
  "session_id": "opaque-high-entropy-value",
  "authorization_url": "https://api.notion.com/v1/oauth/authorize?..."
}
```

The broker creates and stores the OAuth `state`, binds it to the session and callback,
and uses its own registered HTTPS redirect URI for Notion. After validating Notion's
callback and exchanging the authorization code, it redirects to:

`dayline://oauth/notion?session_id=<opaque>&result=success`

The deep link contains no Notion credential. Sessions are single-use and short-lived.

## Complete a session

`POST /v1/notion/oauth/sessions/complete`

```json
{
  "session_id": "opaque-high-entropy-value"
}
```

```json
{
  "access_token": "secret",
  "refresh_token": "secret-or-null",
  "bot_id": "notion-bot-id",
  "workspace_id": "notion-workspace-id",
  "workspace_name": "Example workspace",
  "workspace_icon": null,
  "connection_id": "opaque-connection-id",
  "revocation_token": "separate-high-entropy-capability"
}
```

Completion consumes the session. Responses must set `Cache-Control: no-store`.

## Revoke a connection

`POST /v1/notion/oauth/connections/revoke`

```json
{
  "connection_id": "opaque-connection-id",
  "revocation_token": "separate-high-entropy-capability"
}
```

A successful or already-revoked connection returns `204`. The broker must authenticate
to Notion server-side and must never require the app to put a Notion token in a URL.

## Error contract

The client distinguishes only configuration, cancellation, invalid callback, rejected,
transport, and invalid-response failures. The broker must not return upstream Notion
response bodies or secrets to the app. Error bodies are deliberately ignored by Dayline.
