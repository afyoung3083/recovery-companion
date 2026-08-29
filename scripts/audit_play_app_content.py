"""Audit source-level Google Play App Content assumptions."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

PUBSPEC = ROOT / "mobile" / "pubspec.yaml"
MANIFEST = (
    ROOT
    / "mobile"
    / "android"
    / "app"
    / "src"
    / "main"
    / "AndroidManifest.xml"
)
PRIVACY = ROOT / "docs" / "privacy" / "index.md"
HEALTH = (
    ROOT
    / "docs"
    / "google-play-health-declaration-final.md"
)
APP_CONTENT = (
    ROOT
    / "docs"
    / "google-play-app-content-declarations.md"
)


def require(
    condition: bool,
    message: str,
) -> None:
    if not condition:
        raise SystemExit(message)


pubspec = PUBSPEC.read_text(
    encoding="utf-8"
)

manifest = MANIFEST.read_text(
    encoding="utf-8"
)

privacy = PRIVACY.read_text(
    encoding="utf-8"
)

health = HEALTH.read_text(
    encoding="utf-8"
)

app_content = APP_CONTENT.read_text(
    encoding="utf-8"
)

# Current source-level ads evidence.
for ad_token in (
    "google_mobile_ads",
    "admob",
):
    require(
        ad_token not in pubspec.lower(),
        "Advertising SDK detected. "
        "Reassess Play Ads declaration.",
    )

require(
    'android:label="Recovery Companion"'
    in manifest,
    "Production app label not found.",
)

require(
    "Mental and Behavioral Health"
    in health,
    "Health declaration category missing.",
)

require(
    "not a medical device"
    in health,
    "Medical-device disclaimer missing.",
)

require(
    "not an emergency"
    in health,
    "Emergency-service disclaimer missing.",
)

require(
    "Recovery information stored on your device"
    in privacy,
    "Privacy policy local-data disclosure missing.",
)

require(
    "Information sent for optional online features"
    in privacy,
    "Privacy policy online-processing disclosure missing.",
)

require(
    "No, Recovery Companion does not contain ads"
    in app_content,
    "Ads declaration missing.",
)

require(
    "Adults"
    in app_content,
    "Adult target-audience recommendation missing.",
)

print("Google Play App Content source audit passed.")
print("Verified: no known mobile advertising SDK in pubspec.")
print("Verified: health declaration identifies Mental and Behavioral Health.")
print("Verified: health/medical disclaimers are documented.")
print("Verified: privacy policy covers local and optional online processing.")
print(
    "Not determined by source: final IARC rating, Play reviewer decisions, "
    "or exact age-group controls shown by the current Play Console."
)
