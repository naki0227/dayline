# Release and deployment

Dayline uses commit-based development on `main` and tag-based delivery.

## Intended flow

1. Every push to `main` runs role-specific blocking CI and advisory quality
   reporting.
2. A `vMAJOR.MINOR.PATCH` tag supplies `MARKETING_VERSION`.
3. GitHub Actions' monotonically increasing run number supplies the build number.
4. CD imports a distribution certificate into an ephemeral keychain.
5. CD obtains the provisioning profile through App Store Connect API credentials.
6. Xcode archives and exports the IPA.
7. Apple CLI tooling validates or uploads the IPA.
8. App Store Connect metadata and build association are applied after processing.

This follows the proven `useful_map` release shape. Its current implementation is
`xcodebuild` + `xcrun altool` + `scripts/asc.py`; adoption of a distinct
AppleDevCLI binary must be recorded in a later ADR once its exact command and
authentication contract are confirmed.

## Safety rules

- Tag delivery is added only after the app target, bundle identifier, team,
  App Store Connect app record, and export options exist.
- Manual dispatch defaults to dry-run validation.
- `main` pushes never upload to Apple.
- Signing keys and API private keys exist only in GitHub Secrets and ephemeral
  runner paths.
- CD depends on the same blocking checks as normal commits.
- Release concurrency never cancels an in-progress upload.

## Required secrets

- `DIST_CERT_P12`
- `DIST_CERT_PASSWORD`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8`

