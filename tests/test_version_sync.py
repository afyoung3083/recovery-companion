import re
from pathlib import Path

from app.version import __version__


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PUBSPEC_FILE = PROJECT_ROOT / "mobile" / "pubspec.yaml"

SEMVER_PATTERN = re.compile(
    r"^\d+\.\d+\.\d+$"
)

FLUTTER_VERSION_PATTERN = re.compile(
    r"^version:\s*"
    r"(\d+\.\d+\.\d+)"
    r"\+"
    r"(\d+)"
    r"\s*$",
    re.MULTILINE,
)


def test_flutter_semantic_version_matches_canonical_version():
    assert SEMVER_PATTERN.fullmatch(
        __version__
    ), (
        "app/version.py must contain a semantic "
        "X.Y.Z product version."
    )

    pubspec = PUBSPEC_FILE.read_text(
        encoding="utf-8"
    )

    match = FLUTTER_VERSION_PATTERN.search(
        pubspec
    )

    assert match is not None, (
        "mobile/pubspec.yaml must contain "
        "'version: X.Y.Z+N'."
    )

    flutter_semantic_version = match.group(1)
    flutter_build_number = int(
        match.group(2)
    )

    assert (
        flutter_semantic_version
        == __version__
    ), (
        "Flutter semantic version must match "
        "app/version.py. "
        f"Canonical={__version__}, "
        f"Flutter={flutter_semantic_version}."
    )

    assert flutter_build_number > 0
