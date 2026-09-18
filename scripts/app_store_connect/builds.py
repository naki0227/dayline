"""Build processing wait and App Store version association."""

from __future__ import annotations

import time
from collections.abc import Callable
from typing import Any

from .apps import require_app, require_editable_version
from .client import AppStoreClient
from .config import AppStoreConfig


def attach_latest_build(
    client: AppStoreClient,
    config: AppStoreConfig,
    *,
    timeout_seconds: float = 20 * 60,
    poll_seconds: float = 30,
    monotonic: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> str:
    app = require_app(client, config)
    version = require_editable_version(client, app["id"])
    deadline = monotonic() + timeout_seconds

    while True:
        builds = client.get(
            "/v1/builds",
            params={
                "filter[app]": app["id"],
                "filter[preReleaseVersion.version]": version["attributes"][
                    "versionString"
                ],
                "sort": "-uploadedDate",
                "limit": 10,
            },
        )["data"]
        ready = [
            build
            for build in builds
            if build["attributes"]["processingState"] == "VALID"
        ]
        if ready:
            break
        if monotonic() >= deadline:
            states = [build["attributes"]["processingState"] for build in builds]
            raise TimeoutError(f"Build did not become VALID: {states or ['not found']}")
        sleep(poll_seconds)

    build: dict[str, Any] = ready[0]
    client.patch(
        f"/v1/appStoreVersions/{version['id']}",
        {
            "data": {
                "type": "appStoreVersions",
                "id": version["id"],
                "relationships": {
                    "build": {"data": {"type": "builds", "id": build["id"]}}
                },
            }
        },
    )
    build_number: str = build["attributes"]["version"]
    return build_number


def wait_for_testflight_build(
    client: AppStoreClient,
    config: AppStoreConfig,
    *,
    marketing_version: str,
    build_number: str,
    timeout_seconds: float = 30 * 60,
    poll_seconds: float = 30,
    monotonic: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> str:
    """Wait for the exact uploaded build; do not attach it to an App Store version."""
    if not marketing_version or not build_number:
        raise ValueError("Marketing version and build number are required")

    app = require_app(client, config)
    deadline = monotonic() + timeout_seconds
    while True:
        builds = client.get(
            "/v1/builds",
            params={
                "filter[app]": app["id"],
                "filter[version]": build_number,
                "limit": 20,
            },
        )["data"]
        for build in builds:
            prerelease = client.get(f"/v1/builds/{build['id']}/preReleaseVersion")[
                "data"
            ]
            if prerelease["attributes"]["version"] != marketing_version:
                continue
            state = build["attributes"]["processingState"]
            if state == "VALID":
                return build["id"]
            if state in ("FAILED", "INVALID"):
                raise RuntimeError(f"TestFlight build processing failed: {state}")

        if monotonic() >= deadline:
            raise TimeoutError("Exact TestFlight build did not become VALID")
        sleep(poll_seconds)
