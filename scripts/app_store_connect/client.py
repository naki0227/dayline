"""Typed HTTP boundary for App Store Connect API."""

from __future__ import annotations

from typing import Any, Protocol

import requests

from .auth import create_token
from .config import AppStoreConfig

JsonObject = dict[str, Any]


class AppStoreClient(Protocol):
    def get(self, path: str, **kwargs: Any) -> JsonObject: ...

    def post(self, path: str, payload: JsonObject) -> JsonObject: ...

    def patch(self, path: str, payload: JsonObject) -> JsonObject: ...


class Client:
    base_url = "https://api.appstoreconnect.apple.com"

    def __init__(self, config: AppStoreConfig) -> None:
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bearer {create_token(config)}"

    def request(self, method: str, path: str, **kwargs: Any) -> JsonObject:
        url = path if path.startswith("http") else f"{self.base_url}{path}"
        response = self.session.request(method, url, timeout=60, **kwargs)
        if not response.ok:
            raise RuntimeError(
                f"App Store Connect {method} {path} failed "
                f"with HTTP {response.status_code}"
            )
        if not response.content:
            return {}
        result: JsonObject = response.json()
        return result

    def get(self, path: str, **kwargs: Any) -> JsonObject:
        return self.request("GET", path, **kwargs)

    def post(self, path: str, payload: JsonObject) -> JsonObject:
        return self.request("POST", path, json=payload)

    def patch(self, path: str, payload: JsonObject) -> JsonObject:
        return self.request("PATCH", path, json=payload)
