from pathlib import Path
from typing import Any
from unittest import TestCase

from app_store_connect.builds import wait_for_testflight_build
from app_store_connect.config import AppStoreConfig


class FakeClient:
    def __init__(self, states: list[str]) -> None:
        self.states = iter(states)
        self.build_queries: list[dict[str, Any]] = []

    def get(self, path: str, **kwargs: Any) -> dict[str, Any]:
        if path == "/v1/apps":
            return {"data": [{"id": "app-id"}]}
        if path == "/v1/builds":
            self.build_queries.append(kwargs["params"])
            return {
                "data": [
                    {"id": "wrong", "attributes": {"processingState": "VALID"}},
                    {
                        "id": "expected",
                        "attributes": {"processingState": next(self.states)},
                    },
                ]
            }
        if path.startswith("/v1/builds/"):
            version = "0.9.0" if path.endswith("wrong/preReleaseVersion") else "1.2.3"
            return {"data": {"attributes": {"version": version}}}
        raise AssertionError(f"Unexpected GET {path}")

    def post(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        raise AssertionError(f"Unexpected POST {path} {payload}")

    def patch(self, path: str, payload: dict[str, Any]) -> dict[str, Any]:
        raise AssertionError(f"Unexpected PATCH {path} {payload}")


class TestFlightBuildTests(TestCase):
    def setUp(self) -> None:
        self.config = AppStoreConfig(
            key_id="key",
            issuer_id="issuer",
            bundle_id="com.enludus.Dayline",
            profile_name="Dayline App Store",
            private_keys_dir=Path("/tmp/keys"),
            profiles_dir=Path("/tmp/profiles"),
        )

    def test_waits_for_exact_build_and_never_attaches_app_store_version(self) -> None:
        client = FakeClient(["PROCESSING", "VALID"])
        times = iter([0.0, 1.0, 2.0])

        result = wait_for_testflight_build(
            client,
            self.config,
            marketing_version="1.2.3",
            build_number="42",
            monotonic=lambda: next(times),
            sleep=lambda _: None,
        )

        self.assertEqual(result, "expected")
        self.assertEqual(
            client.build_queries,
            [
                {"filter[app]": "app-id", "filter[version]": "42", "limit": 20},
                {"filter[app]": "app-id", "filter[version]": "42", "limit": 20},
            ],
        )

    def test_failed_processing_stops_without_using_other_valid_build(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "processing failed: FAILED"):
            wait_for_testflight_build(
                FakeClient(["FAILED"]),
                self.config,
                marketing_version="1.2.3",
                build_number="42",
            )

    def test_requires_exact_version_and_build(self) -> None:
        with self.assertRaisesRegex(ValueError, "required"):
            wait_for_testflight_build(
                FakeClient(["VALID"]),
                self.config,
                marketing_version="",
                build_number="42",
            )
