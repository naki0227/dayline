#!/usr/bin/env python3
"""Render non-secret App Store export settings from validated environment values."""

from __future__ import annotations

import argparse
import os
import plistlib
from collections.abc import Mapping
from pathlib import Path


class ExportConfigurationError(ValueError):
    """A required export configuration value is missing."""


def export_options(environment: Mapping[str, str]) -> dict[str, object]:
    team_id = environment.get("APPLE_TEAM_ID")
    if not team_id:
        raise ExportConfigurationError("APPLE_TEAM_ID is required")

    bundle_id = environment.get("BUNDLE_ID", "com.enludus.Dayline")
    profile_name = environment.get("ASC_PROFILE_NAME", "Dayline App Store")
    return {
        "method": "app-store-connect",
        "teamID": team_id,
        "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "provisioningProfiles": {bundle_id: profile_name},
        "uploadSymbols": True,
        "destination": "export",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    try:
        values = export_options(os.environ)
    except ExportConfigurationError as error:
        parser.exit(1, f"error: {error}\n")

    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    with arguments.output.open("wb") as output:
        plistlib.dump(values, output, sort_keys=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
