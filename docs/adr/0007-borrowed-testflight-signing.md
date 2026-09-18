# ADR 0007: Borrow signing in useful-map for Dayline TestFlight

- Status: Accepted
- Date: 2026-09-18

## Context and problem

Dayline has a working release pipeline but no GitHub signing Secrets. The same
Apple account already has five signing Secrets in `naki0227/useful-map`. GitHub
does not expose existing Secret values for copying, and moving them through logs
or artifacts would be unsafe. The Dayline bundle ID is `com.enludus.Dayline`.

## Options

1. Ask the owner to find and duplicate all five signing credentials into Dayline.
2. Run a dedicated `useful-map` workflow that checks out a pinned Dayline commit.
3. Revert to Xcode cloud signing.

## Decision and reasons

Use option 2 for the first TestFlight build. The workflow is manual-only,
verifies the SHA is exactly the current Dayline `main` tip, runs Dayline CI, and
uses the existing `useful-map` Secrets solely in its ephemeral macOS runner.
The first run defaults to signed validation without upload. A separate explicit
run uploads, then waits for the exact version/build to become `VALID`.

This keeps the credential boundary in one repository and does not require
recovery or transport of private key material. Dayline retains its own tag CD
for a later migration when credentials are installed there.

## Benefits and drawbacks

- Benefits: no Secret copying; deterministic source revision; no accidental
  `main`-push upload; independent dry-run; exact TestFlight build verification.
- Drawbacks: release is manual rather than a single Dayline tag push; the
  workflow source has an installed copy in another repository; `useful-map`
  maintainers can run a Dayline build with their signing credentials.

## Reconsider when

- Dayline has its own signing Secrets or an organization-level Secret scope.
- A GitHub App can dispatch cross-repo workflows without a long-lived token.
- Apple cloud signing becomes reliable for this account.
