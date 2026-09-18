#!/usr/bin/env python3
"""Dayline App Store Connect CLI used by release automation."""

from __future__ import annotations

import argparse
import os

from app_store_connect.apps import print_status
from app_store_connect.builds import attach_latest_build, wait_for_testflight_build
from app_store_connect.client import Client
from app_store_connect.config import AppStoreConfig, ConfigError
from app_store_connect.profiles import install_distribution_profile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("status", "profile", "build", "testflight"))
    arguments = parser.parse_args()

    try:
        config = AppStoreConfig.from_environment()
        client = Client(config)
        if arguments.command == "status":
            print_status(client, config)
        elif arguments.command == "profile":
            destination = install_distribution_profile(client, config)
            print(f"Installed provisioning profile: {destination}")
        elif arguments.command == "build":
            build_number = attach_latest_build(client, config)
            print(f"Attached build {build_number} to the editable App Store version")
        else:
            build_id = wait_for_testflight_build(
                client,
                config,
                marketing_version=os.environ.get("MARKETING_VERSION", ""),
                build_number=os.environ.get("BUILD_NUMBER", ""),
            )
            print(f"TestFlight build processed: {build_id}")
    except (ConfigError, OSError, RuntimeError, TimeoutError, ValueError) as error:
        parser.exit(1, f"error: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
