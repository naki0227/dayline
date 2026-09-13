"""App and editable-version lookup operations."""

from __future__ import annotations

from typing import Any

from .client import AppStoreClient
from .config import AppStoreConfig

EDITABLE_STATES = (
    "PREPARE_FOR_SUBMISSION",
    "REJECTED",
    "DEVELOPER_REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
)


def require_app(client: AppStoreClient, config: AppStoreConfig) -> dict[str, Any]:
    apps = client.get("/v1/apps", params={"filter[bundleId]": config.bundle_id})["data"]
    if not apps:
        raise RuntimeError(
            f"No App Store Connect app exists for {config.bundle_id}. "
            "Create it in App Store Connect first."
        )
    app: dict[str, Any] = apps[0]
    return app


def require_editable_version(client: AppStoreClient, app_id: str) -> dict[str, Any]:
    versions = client.get(
        f"/v1/apps/{app_id}/appStoreVersions",
        params={
            "filter[appStoreState]": ",".join(EDITABLE_STATES),
            "limit": 1,
        },
    )["data"]
    if not versions:
        raise RuntimeError("No editable App Store version is available")
    version: dict[str, Any] = versions[0]
    return version


def print_status(client: AppStoreClient, config: AppStoreConfig) -> None:
    app = require_app(client, config)
    print(f"App: {app['attributes']['name']} ({app['id']})")

    versions = client.get(
        f"/v1/apps/{app['id']}/appStoreVersions", params={"limit": 5}
    )["data"]
    for version in versions:
        attributes = version["attributes"]
        print(f"Version: {attributes['versionString']} / {attributes['appStoreState']}")

    builds = client.get("/v1/builds", params={"filter[app]": app["id"], "limit": 5})[
        "data"
    ]
    for build in builds:
        attributes = build["attributes"]
        print(f"Build: {attributes['version']} / {attributes['processingState']}")
