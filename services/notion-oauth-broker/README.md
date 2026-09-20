# Dayline Notion OAuth broker

Cloudflare Worker that keeps the Notion OAuth client secret outside the iOS binary.
Durable Objects serialize each OAuth session and rate-limit session creation without a
separate database.

## Security properties

- The app callback contains only a 256-bit opaque session capability.
- `callback_url` must exactly equal `dayline://oauth/notion`; open redirects fail closed.
- OAuth state and session ID are the same unpredictable value and expire after ten
  minutes if authorization is not completed.
- Completion is replayable for two minutes to survive a lost response. The alarm then
  erases the refresh token and raw revocation capability while retaining only the access
  token and revocation hash needed for later disconnect.
- Revocation compares SHA-256 capability digests in constant time and calls Notion's
  official `/v1/oauth/revoke` endpoint before deleting all connection storage.
- Session creation is limited to ten attempts per keyed, minute-scoped source-address
  digest. Neither a raw address nor a stable plain hash is stored.
- Requests are capped at 4 KiB. Responses and errors use `Cache-Control: no-store` and
  never include Notion response bodies.

## Local verification

Copy `.dev.vars.example` to the ignored `.dev.vars`, fill development values, then run:

```sh
make oauth-broker-ci
make oauth-broker-dev
```

No test contacts Notion. The test suite injects an in-memory OAuth adapter.
`NOTION_REDIRECT_URI` remains HTTPS in local development because Notion must redirect to
an exact registered URL; use a development Worker or HTTPS tunnel for a real OAuth test.

## Production prerequisites

Create a Notion public connection with Insert Content capability and register:

```text
https://dayline-notion-oauth-broker.<workers-subdomain>.workers.dev/v1/notion/oauth/callback
```

Configure the repository without pasting values into issues or logs:

| GitHub setting                    | Kind     | Purpose                                                    |
| --------------------------------- | -------- | ---------------------------------------------------------- |
| `CLOUDFLARE_API_TOKEN`            | Secret   | Worker/Durable Object deployment                           |
| `CLOUDFLARE_ACCOUNT_ID`           | Variable | Target Cloudflare account                                  |
| `NOTION_CLIENT_ID`                | Variable | Public connection identifier                               |
| `NOTION_CLIENT_SECRET`            | Secret   | Server-side token exchange/revoke                          |
| `RATE_LIMIT_KEY_SECRET`           | Secret   | Random key of at least 32 characters for address digests   |
| `NOTION_REDIRECT_URI`             | Variable | Exact registered HTTPS callback                            |
| `DAYLINE_NOTION_OAUTH_BROKER_URL` | Variable | Worker base URL used by health check and iOS Release build |

The Cloudflare token should be scoped to this account and only the Worker/Durable Object
resources required for deployment. `NOTION_CLIENT_SECRET` and `RATE_LIMIT_KEY_SECRET`
are uploaded as encrypted Worker secrets; the remaining runtime values are Worker
variables. Generate the rate-limit key outside logs, for example with
`openssl rand -base64 32`, and save only its result in the GitHub Secret setting.

## Delivery

Validate locally with `make oauth-broker-ci`. Production deployment is manual or tag
based:

```sh
git tag oauth-broker-v0.1.0
git push origin oauth-broker-v0.1.0
```

`CD / OAuth Broker` re-runs all broker gates, updates the encrypted Worker secret,
deploys, and verifies `/health`. It does not build or distribute the iOS app.
