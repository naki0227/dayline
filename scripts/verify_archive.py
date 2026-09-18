"""Fail release before upload if the archived app identity is not the intended one."""

from __future__ import annotations

import argparse
import plistlib
from pathlib import Path


class ArchiveMismatchError(ValueError):
    """The signed archive does not contain the requested app identity."""


def verify_archive(
    archive: Path, *, bundle_id: str, marketing_version: str, build_number: str
) -> None:
    info_path = archive / "Products/Applications/Dayline.app/Info.plist"
    with info_path.open("rb") as source:
        info = plistlib.load(source)

    expected = {
        "CFBundleIdentifier": bundle_id,
        "CFBundleShortVersionString": marketing_version,
        "CFBundleVersion": build_number,
    }
    for key, value in expected.items():
        actual = info.get(key)
        if actual != value:
            raise ArchiveMismatchError(
                f"Archived {key} mismatch: expected {value!r}, got {actual!r}"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--marketing-version", required=True)
    parser.add_argument("--build-number", required=True)
    args = parser.parse_args()
    try:
        verify_archive(
            args.archive,
            bundle_id=args.bundle_id,
            marketing_version=args.marketing_version,
            build_number=args.build_number,
        )
    except (
        ArchiveMismatchError,
        FileNotFoundError,
        plistlib.InvalidFileException,
    ) as error:
        parser.exit(1, f"error: {error}\n")
    print("Archived app identity matches the requested release")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
