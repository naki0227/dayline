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

This reproduces the proven `useful_map` release shape. In Dayline, “AppleDevCLI”
means the combination of `xcodebuild`, `xcrun altool`, and the responsibility-split
Python client rooted at `scripts/asc.py`.

## Makefile entry points

- `make asc-status`: inspect the app, editable version, and recent builds.
- `make asc-profile`: fetch or create the App Store provisioning profile.
- `make export-ipa`: archive and export a signed IPA.
- `make validate-ipa`: ask Apple to validate without uploading.
- `make upload`: upload the exported IPA.
- `make asc-build`: wait for processing and attach the latest valid build.
- `make release-dry-run`: run the signed build and validation path.
- `make release-upload`: run the upload and build-association path.

## Safety rules

- Tag delivery fails before signing if required Variables or Secrets are absent.
- Manual dispatch defaults to dry-run validation.
- `main` pushes never upload to Apple.
- Signing keys and API private keys exist only in GitHub Secrets and ephemeral
  runner paths.
- CD depends on the same blocking checks as normal commits.
- Release concurrency never cancels an in-progress upload.

## Required repository Variables

- `APPLE_TEAM_ID`
- `DAYLINE_BUNDLE_ID`
- `ASC_PROFILE_NAME`

These are identifiers, not authentication credentials. Keeping them in Variables
avoids hard-coding account-specific values in the repository.

## Required secrets

- `DIST_CERT_P12`
- `DIST_CERT_PASSWORD`
- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8`

`DIST_CERT_P12` and `ASC_KEY_P8` are base64-encoded before saving. CD never
uploads the signed IPA as a public-repository Actions artifact and removes the
temporary keychain and API key at the end of every run.
