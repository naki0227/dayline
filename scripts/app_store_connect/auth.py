"""JWT creation for App Store Connect API."""

from __future__ import annotations

import time

import jwt

from .config import AppStoreConfig


def create_token(config: AppStoreConfig, issued_at: int | None = None) -> str:
    now = int(time.time()) if issued_at is None else issued_at
    private_key = config.private_key_path.read_text(encoding="utf-8")
    return jwt.encode(
        {
            "iss": config.issuer_id,
            "iat": now,
            "exp": now + 15 * 60,
            "aud": "appstoreconnect-v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": config.key_id, "typ": "JWT"},
    )
