# ADR 0008: Keep Notion OAuth secrets behind a broker

## Status

Accepted

## Context

Notion public connections use OAuth authorization codes. Exchanging and refreshing those
codes requires the connection's client secret. Dayline is a distributed iOS application,
so any secret embedded in the app bundle must be treated as public.

The existing development flow stores a manually issued token in the device-only Keychain.
It is useful for local development, but it is not an acceptable product onboarding flow.

## Decision

Dayline uses a small HTTPS OAuth broker with three operations:

- `POST /v1/notion/oauth/sessions` starts a server-owned OAuth transaction and returns
  an authorization URL plus an opaque session identifier.
- `POST /v1/notion/oauth/sessions/complete` exchanges the completed opaque session for
  the Notion token pair and non-secret workspace metadata.
- `POST /v1/notion/oauth/connections/revoke` revokes a connection using a separate,
  high-entropy revocation capability.

The broker owns the Notion client secret, authorization-code exchange, refresh-token
rotation, server-side state validation, and remote revocation. The app opens the returned
authorization URL with `ASWebAuthenticationSession`; the callback carries only an opaque
session identifier and never carries a Notion access or refresh token.

The app stores the resulting token pair, revocation capability, and workspace metadata as
one versioned device-only Keychain record. It retains read compatibility with the old
manual token item for development, but the product UI never asks a user to paste a token.

OAuth connection state is independent from the existing `ActionProposal` flow. Connecting
grants credentials; every Notion page creation still requires deterministic Rust policy
evaluation and explicit user confirmation.

## Alternatives considered

### Embed the client secret in the app

Rejected. An iOS binary cannot keep a client secret confidential.

### Exchange the authorization code directly from the app

Rejected because Notion's token endpoint requires HTTP Basic authentication with the
connection client ID and client secret.

### Keep manual integration tokens as the product flow

Rejected because it makes normal users create an integration and copy credentials. It
remains only as a migration/development compatibility path.

## Consequences

### Benefits

- No Notion client secret or authorization code is stored in or logged by the app.
- OAuth CSRF/state handling and token lifecycle have one auditable server boundary.
- The iOS UI can show workspace identity and connect/disconnect/reconnect states.
- Existing explicit write confirmation remains unchanged.

### Costs

- A highly available HTTPS broker and a registered public Notion connection are required.
- Broker configuration and redirect URLs must be managed per environment.
- Revocation failures need content-free diagnostics while local credentials are still
  removed immediately.

## Revisit when

- Notion supports a native-app flow with PKCE that does not require a client secret.
- Dayline introduces a general account backend that should own all connector sessions.
- Multi-device token synchronization becomes an explicit product requirement.
