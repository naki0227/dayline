from pathlib import Path
from typing import Any
from unittest import TestCase

from app_store_connect.builds import attach_latest_build
from app_store_connect.config import AppStoreConfig


class FakeClient:
    attached_payload: dict[str, Any] | None = None

    def get(self, path: str, **kwargs: Any) -> dict[str, Any]:
        if path == "/v1/apps":
            return {"data": [{"id": "app-id", "attributes": {"name": "Dayline"}}]}
        if path == "/v1/apps/app-id/appStoreVersions":
            return {
                "data": [
                    {
                        "id": "version-id",
                        "attributes": {"versionString": "1.2.3"},
                    }
                ]
            }
        if path == "/v1/builds":
            return {
                "data": [
                    {
                        "id": "build-id",
                        "attributes": {
                            "version": "42",
                            "processingState": "VALID",
                        },
                    }
                ]
            }
        raise AssertionError(f"Unexpected GET {path} {kwargs}")

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        raise AssertionError(f"Unexpected POST {path} {payload}")

    def patch(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        self.attached_payload = payload
        return {}


class BuildAssociationTests(TestCase):
    def test_attaches_latest_valid_build(self) -> None:
        client = FakeClient()
        config = AppStoreConfig(
            key_id="key",
            issuer_id="issuer",
            bundle_id="com.dayline.Dayline",
            profile_name="Dayline App Store",
            private_keys_dir=Path("/tmp/keys"),
            profiles_dir=Path("/tmp/profiles"),
        )

        build_number = attach_latest_build(client, config)

        self.assertEqual(build_number, "42")
        self.assertEqual(
            client.attached_payload,
            {
                "data": {
                    "type": "appStoreVersions",
                    "id": "version-id",
                    "relationships": {
                        "build": {"data": {"type": "builds", "id": "build-id"}}
                    },
                }
            },
        )
