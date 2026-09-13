from unittest import TestCase

from render_export_options import ExportConfigurationError, export_options


class ExportOptionsTests(TestCase):
    def test_keeps_team_id_out_of_repository_defaults(self) -> None:
        options = export_options(
            {
                "APPLE_TEAM_ID": "TEAM_FROM_SECRET",
                "BUNDLE_ID": "com.example.Dayline",
                "ASC_PROFILE_NAME": "Example Profile",
            }
        )

        self.assertEqual(options["teamID"], "TEAM_FROM_SECRET")
        self.assertEqual(
            options["provisioningProfiles"],
            {"com.example.Dayline": "Example Profile"},
        )

    def test_requires_team_id(self) -> None:
        with self.assertRaises(ExportConfigurationError):
            export_options({})
