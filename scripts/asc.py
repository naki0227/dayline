#!/usr/bin/env python3
"""Dayline App Store Connect CLI used by release automation."""

from __future__ import annotations

import argparse

from app_store_connect.apps import print_status
from app_store_connect.builds import attach_latest_build
from app_store_connect.client import Client
from app_store_connect.config import AppStoreConfig, ConfigError
from app_store_connect.profiles import install_distribution_profile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("status", "profile", "build"))
    arguments = parser.parse_args()

    try:
        config = AppStoreConfig.from_environment()
        client = Client(config)
        if arguments.command == "status":
            print_status(client, config)
        elif arguments.command == "profile":
            destination = install_distribution_profile(client, config)
            print(f"Installed provisioning profile: {destination}")
        else:
            build_number = attach_latest_build(client, config)
            print(f"Attached build {build_number} to the editable App Store version")
    except (ConfigError, OSError, RuntimeError, TimeoutError) as error:
        parser.exit(1, f"error: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
