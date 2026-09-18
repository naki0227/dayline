import plistlib
import tempfile
from pathlib import Path
from unittest import TestCase

from verify_archive import ArchiveMismatchError, verify_archive


class VerifyArchiveTests(TestCase):
    def test_accepts_exact_identity(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory)
            self._write_info(archive, version="1.0", build="7")
            verify_archive(
                archive,
                bundle_id="com.enludus.Dayline",
                marketing_version="1.0",
                build_number="7",
            )

    def test_rejects_hard_coded_build_before_upload(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory)
            self._write_info(archive, version="1.0", build="1")
            with self.assertRaisesRegex(ArchiveMismatchError, "CFBundleVersion"):
                verify_archive(
                    archive,
                    bundle_id="com.enludus.Dayline",
                    marketing_version="1.0",
                    build_number="7",
                )

    def test_rejects_wrong_marketing_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory)
            self._write_info(archive, version="0.1.0", build="7")
            with self.assertRaisesRegex(
                ArchiveMismatchError, "CFBundleShortVersionString"
            ):
                verify_archive(
                    archive,
                    bundle_id="com.enludus.Dayline",
                    marketing_version="1.0",
                    build_number="7",
                )

    def test_rejects_wrong_bundle_identifier(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory)
            self._write_info(archive, version="1.0", build="7", bundle="other")
            with self.assertRaisesRegex(ArchiveMismatchError, "CFBundleIdentifier"):
                verify_archive(
                    archive,
                    bundle_id="com.enludus.Dayline",
                    marketing_version="1.0",
                    build_number="7",
                )

    def test_rejects_missing_archive(self) -> None:
        with (
            tempfile.TemporaryDirectory() as directory,
            self.assertRaises(FileNotFoundError),
        ):
            verify_archive(
                Path(directory),
                bundle_id="com.enludus.Dayline",
                marketing_version="1.0",
                build_number="7",
            )

    @staticmethod
    def _write_info(
        archive: Path, *, version: str, build: str, bundle: str = "com.enludus.Dayline"
    ) -> None:
        info_path = archive / "Products/Applications/Dayline.app/Info.plist"
        info_path.parent.mkdir(parents=True)
        with info_path.open("wb") as destination:
            plistlib.dump(
                {
                    "CFBundleIdentifier": bundle,
                    "CFBundleShortVersionString": version,
                    "CFBundleVersion": build,
                },
                destination,
            )
