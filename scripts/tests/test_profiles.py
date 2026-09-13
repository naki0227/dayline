import base64
import tempfile
from pathlib import Path
from typing import Any
from unittest import TestCase

from app_store_connect.config import AppStoreConfig
from app_store_connect.profiles import install_distribution_profile


class FakeClient:
    def get(self, path: str, **kwargs: Any) -> dict[str, Any]:
        if path == "/v1/bundleIds":
            return {"data": [{"id": "bundle-id"}]}
        if path == "/v1/profiles":
            return {"data": [{"id": "profile-id"}]}
        if path == "/v1/profiles/profile-id":
            return {
                "data": {
                    "attributes": {
                        "uuid": "PROFILE-UUID",
                        "profileContent": base64.b64encode(b"profile").decode(),
                    }
                }
            }
        raise AssertionError(f"Unexpected GET {path} {kwargs}")

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        raise AssertionError(f"Unexpected POST {path} {payload}")

    def patch(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        raise AssertionError(f"Unexpected PATCH {path} {payload}")


class DistributionProfileTests(TestCase):
    def test_installs_active_profile(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = AppStoreConfig(
                key_id="key",
                issuer_id="issuer",
                bundle_id="com.dayline.Dayline",
                profile_name="Dayline App Store",
                private_keys_dir=Path(directory),
                profiles_dir=Path(directory),
            )

            destination = install_distribution_profile(FakeClient(), config)

            self.assertEqual(destination.read_bytes(), b"profile")
            self.assertEqual(destination.name, "PROFILE-UUID.mobileprovision")
