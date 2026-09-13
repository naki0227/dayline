"""Distribution provisioning profile acquisition."""

from __future__ import annotations

import base64
from pathlib import Path
from typing import Any

from .client import AppStoreClient
from .config import AppStoreConfig


def install_distribution_profile(
    client: AppStoreClient, config: AppStoreConfig
) -> Path:
    identifiers = client.get(
        "/v1/bundleIds",
        params={"filter[identifier]": config.bundle_id, "limit": 1},
    )["data"]
    if not identifiers:
        raise RuntimeError(
            f"{config.bundle_id} is not registered in Certificates, "
            "Identifiers & Profiles"
        )

    profiles = client.get(
        "/v1/profiles",
        params={
            "filter[name]": config.profile_name,
            "filter[profileState]": "ACTIVE",
            "limit": 1,
        },
    )["data"]
    profile = (
        client.get(f"/v1/profiles/{profiles[0]['id']}")["data"]
        if profiles
        else _create_profile(client, config, identifiers[0]["id"])
    )

    config.profiles_dir.mkdir(parents=True, exist_ok=True)
    destination = config.profiles_dir / (
        f"{profile['attributes']['uuid']}.mobileprovision"
    )
    destination.write_bytes(base64.b64decode(profile["attributes"]["profileContent"]))
    return destination


def _create_profile(
    client: AppStoreClient, config: AppStoreConfig, bundle_identifier_id: str
) -> dict[str, Any]:
    certificates = [
        certificate
        for certificate in client.get("/v1/certificates", params={"limit": 50})["data"]
        if certificate["attributes"]["certificateType"] == "DISTRIBUTION"
    ]
    if not certificates:
        raise RuntimeError("No Apple Distribution certificate is available")

    result = client.post(
        "/v1/profiles",
        {
            "data": {
                "type": "profiles",
                "attributes": {
                    "name": config.profile_name,
                    "profileType": "IOS_APP_STORE",
                },
                "relationships": {
                    "bundleId": {
                        "data": {
                            "type": "bundleIds",
                            "id": bundle_identifier_id,
                        }
                    },
                    "certificates": {
                        "data": [
                            {"type": "certificates", "id": certificate["id"]}
                            for certificate in certificates
                        ]
                    },
                },
            }
        },
    )
    profile: dict[str, Any] = result["data"]
    return profile
