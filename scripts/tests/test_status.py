from pathlib import Path
from typing import Any
from unittest import TestCase
from unittest.mock import patch

from app_store_connect.apps import print_status
from app_store_connect.config import AppStoreConfig


class FakeStatusClient:
    def get(self, path: str, **kwargs: Any) -> dict[str, Any]:
        if path == "/v1/apps":
            return {"data": [{"id": "app-id", "attributes": {"name": "Dayline"}}]}
        if path == "/v1/apps/app-id/appStoreVersions":
            return {"data": []}
        if path == "/v1/builds":
            return {"data": []}
        if path == "/v1/apps/app-id/buildUploads":
            return {
                "data": [
                    {
                        "attributes": {
                            "cfBundleShortVersionString": "0.1.0",
                            "cfBundleVersion": "5",
                            "state": {
                                "state": "FAILED",
                                "errors": [
                                    {"code": "ITMS-90000", "detail": "private detail"}
                                ],
                            },
                        }
                    }
                ]
            }
        raise AssertionError(f"Unexpected GET {path}")

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        raise AssertionError(f"Unexpected POST {path} {payload}")

    def patch(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        raise AssertionError(f"Unexpected PATCH {path} {payload}")


class AppStoreStatusTests(TestCase):
    def test_prints_upload_state_and_code_without_private_detail(self) -> None:
        config = AppStoreConfig(
            key_id="key",
            issuer_id="issuer",
            bundle_id="com.enludus.Dayline",
            profile_name="Dayline App Store",
            private_keys_dir=Path("/tmp/keys"),
            profiles_dir=Path("/tmp/profiles"),
        )

        with patch("builtins.print") as output:
            print_status(FakeStatusClient(), config)

        lines = [call.args[0] for call in output.call_args_list]
        self.assertIn("Upload: 0.1.0 (5) / FAILED", lines)
        self.assertIn("Upload error codes: ITMS-90000", lines)
        self.assertNotIn("private detail", "\n".join(lines))
