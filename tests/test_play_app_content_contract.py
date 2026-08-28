from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def test_health_declaration_is_recovery_support_not_medical_device():
    declaration = (
        ROOT
        / "docs"
        / "google-play-health-declaration-final.md"
    ).read_text(
        encoding="utf-8"
    )

    assert "Mental and Behavioral Health" in declaration
    assert "not a medical device" in declaration
    assert "does not diagnose" in declaration
    assert "not an emergency" in declaration


def test_app_content_declares_no_ads_from_current_product():
    content = (
        ROOT
        / "docs"
        / "google-play-app-content-declarations.md"
    ).read_text(
        encoding="utf-8"
    )

    assert (
        "No, Recovery Companion does not contain ads"
        in content
    )

    assert "Adults" in content
    assert "IARC" in content


def test_store_listing_avoids_medical_treatment_claim():
    listing = (
        ROOT
        / "docs"
        / "google-play-store-listing.md"
    ).read_text(
        encoding="utf-8"
    )

    assert "not a medical device" in listing
    assert "does not provide diagnosis or medical treatment" in listing
    assert "not an emergency or crisis-response service" in listing
