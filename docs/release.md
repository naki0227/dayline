# Release and TestFlight deployment

Dayline uses commit-based development on `main`. The original Dayline-local tag
workflow remains available when its own signing Secrets are configured. Until then,
the dedicated `useful-map` manual workflow builds a pinned Dayline `main` commit
using the existing `useful-map` signing Secrets without copying them between repos.

## Intended flow

1. Every push to `main` runs role-specific blocking CI and advisory quality
   reporting.
2. A `vMAJOR.MINOR.PATCH` tag supplies `MARKETING_VERSION`.
3. GitHub Actions' monotonically increasing run number supplies the build number.
4. CD imports a distribution certificate into an ephemeral keychain.
5. CD obtains the provisioning profile through App Store Connect API credentials.
6. Xcode archives and exports the IPA.
7. Apple CLI tooling validates or uploads the IPA.
8. For TestFlight, wait until the exact uploaded marketing version and build number
   becomes `VALID`. Do not attach an arbitrary latest build to an App Store version.

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
- `make asc-testflight`: wait for the exact uploaded build to finish processing.
- `make release-dry-run`: run the signed build and validation path.
- `make release-upload`: run the upload and TestFlight processing check.

## Borrowed useful-map credentials

The workflow source is `deployment/useful-map-dayline-testflight.yml`; its installed
copy is `.github/workflows/dayline-testflight.yml` in `naki0227/useful-map`.
It only runs by manual dispatch, accepts an exact 40-character Dayline SHA, and
requires that SHA to still be the Dayline `main` tip. Its `dry_run` input defaults
to `true`. The job runs Dayline's blocking CI before signing, then checks the App
Store Connect app record, archives and validates the signed IPA. A separate
`dry_run=false` dispatch uploads and waits for the exact TestFlight build.

`useful-map` holds the five existing signing Secrets. Its repository Variables
`APPLE_TEAM_ID`, `DAYLINE_BUNDLE_ID`, and `ASC_PROFILE_NAME` select Dayline's team,
bundle ID, and profile. Never paste credentials into a workflow input, issue,
commit, or chat. The signed IPA is not uploaded as a public Actions artifact.

For an internal tester, an App Store Connect user must have access to the app and
TestFlight's App Store Connect Users group, or be assigned to another internal
group. An external tester requires a separate group and Apple's TestFlight review.
The workflow only verifies build processing; it does not invite testers or submit
the app for App Store review.

If Apple accepts an upload but build processing takes longer than the 30-minute
polling window, do not upload the same build number again. Run the read-only
`deployment/useful-map-dayline-status.yml` workflow in `useful-map` to inspect
App Store Connect first. A successful IPA transfer alone does not mean the build
is ready for TestFlight.

Once the installed workflow and app record are ready, run a dry-run using the
current `main` SHA, inspect its GitHub Actions result, then deliberately dispatch
with `dry_run=false`. Do not push a Dayline `v*` tag while its local signing Secrets
are absent; that legacy workflow will fail before signing.

## Safety rules

- Tag delivery fails before signing if required Variables or Secrets are absent.
- The borrowed workflow never transfers the `useful-map` Secrets to Dayline's
  GitHub settings, logs, or artifacts.
- Manual dispatch defaults to dry-run validation.
- `main` pushes never upload to Apple.
- Signing keys and API private keys exist only in GitHub Secrets and ephemeral
  runner paths.
- CD depends on the same blocking checks as normal commits.
- Release concurrency never cancels an in-progress upload.
- App Store Connect HTTP error bodies are omitted from logs.

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
