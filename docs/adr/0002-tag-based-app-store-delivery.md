# ADR 0002: Tag-based App Store delivery

- Status: Accepted
- Date: 2026-09-13

## Context

Dayline is developed through small commits directly on `main`. App Store delivery
must be intentional and independent from ordinary commits. The established
`useful_map` process already handles local signing and App Store Connect API
automation reliably.

## Problem

Automatic deployment on every `main` commit risks accidental uploads. Cloud
signing is unreliable for the existing CI account, while committing account or
credential material would expose unnecessary data in a public repository.

## Options

1. Upload on every `main` commit using Xcode cloud signing.
2. Use a third-party release system.
3. Reproduce the `useful_map` tag flow with an ephemeral keychain, `xcodebuild`,
   `xcrun altool`, and a small App Store Connect API CLI.

## Decision

Use option 3. A `v*` tag uploads; manual dispatch defaults to Apple validation
without upload. Marketing version comes from the tag and build number comes from
the GitHub run number.

Non-secret account identifiers are Repository Variables. Certificates,
passwords, key IDs, issuer IDs, and private key material are GitHub Secrets. The
signed IPA is not retained as an Actions artifact because the repository is
public.

## Benefits

- Explicit release intent and repeatable monotonically increasing build numbers.
- Signing materials exist only in an ephemeral runner context.
- Local Makefile commands and CD execute the same release operations.
- Python API responsibilities are split and unit-testable.

## Drawbacks

- Certificate renewal and App Store Connect registration remain operational work.
- Apple API or `altool` changes require adapter maintenance.
- Live upload cannot be tested without credentials and a registered app record.

## Reconsider when

- Apple removes `altool` or changes App Store Connect authentication.
- Cloud signing becomes reliable and offers a smaller security surface.
- A supported first-party CLI replaces the current API operations.

