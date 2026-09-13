from pathlib import Path
from unittest import TestCase

from app_store_connect.config import AppStoreConfig, ConfigError


class AppStoreConfigTests(TestCase):
    def test_reads_required_credentials_and_safe_defaults(self) -> None:
        config = AppStoreConfig.from_environment(
            {
                "ASC_KEY_ID": "KEY123",
                "ASC_ISSUER_ID": "issuer",
                "HOME": "/tmp/dayline-test-home",
            }
        )

        self.assertEqual(config.bundle_id, "com.dayline.Dayline")
        self.assertEqual(config.profile_name, "Dayline App Store")
        self.assertEqual(
            config.private_key_path,
            Path(
                "/tmp/dayline-test-home/.appstoreconnect/private_keys/AuthKey_KEY123.p8"
            ),
        )

    def test_rejects_missing_credentials(self) -> None:
        with self.assertRaises(ConfigError):
            AppStoreConfig.from_environment({})
