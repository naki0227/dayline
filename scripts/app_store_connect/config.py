"""Validated environment configuration for App Store Connect commands."""

from __future__ import annotations

import os
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path


class ConfigError(ValueError):
    """Required App Store Connect configuration is missing."""


@dataclass(frozen=True)
class AppStoreConfig:
    key_id: str
    issuer_id: str
    bundle_id: str
    profile_name: str
    private_keys_dir: Path
    profiles_dir: Path

    @classmethod
    def from_environment(
        cls, environment: Mapping[str, str] | None = None
    ) -> AppStoreConfig:
        values = os.environ if environment is None else environment
        key_id = values.get("ASC_KEY_ID")
        issuer_id = values.get("ASC_ISSUER_ID")
        if not key_id or not issuer_id:
            raise ConfigError("ASC_KEY_ID and ASC_ISSUER_ID are required")

        home = Path(values.get("HOME", str(Path.home())))
        return cls(
            key_id=key_id,
            issuer_id=issuer_id,
            bundle_id=values.get("BUNDLE_ID", "com.dayline.Dayline"),
            profile_name=values.get("ASC_PROFILE_NAME", "Dayline App Store"),
            private_keys_dir=Path(
                values.get(
                    "ASC_PRIVATE_KEYS_DIR",
                    str(home / ".appstoreconnect" / "private_keys"),
                )
            ),
            profiles_dir=Path(
                values.get(
                    "ASC_PROFILES_DIR",
                    str(home / "Library" / "MobileDevice" / "Provisioning Profiles"),
                )
            ),
        )

    @property
    def private_key_path(self) -> Path:
        return self.private_keys_dir / f"AuthKey_{self.key_id}.p8"
