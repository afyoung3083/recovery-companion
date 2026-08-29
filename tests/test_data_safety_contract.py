from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def test_openai_requests_disable_response_storage():
    source = (
        ROOT
        / "app"
        / "ai_client.py"
    ).read_text(
        encoding="utf-8"
    )

    assert "responses.create(" in source
    assert "store=False" in source


def test_data_safety_evidence_does_not_claim_zdr():
    evidence = (
        ROOT
        / "docs"
        / "google-play-data-safety-evidence.md"
    ).read_text(
        encoding="utf-8"
    )

    assert (
        "Do not classify Recovery Companion AI processing "
        "as ephemeral"
        in evidence
    )

    assert (
        "has not established evidence"
        in evidence
    )

    assert (
        "Sharing"
        in evidence
    )


def test_data_safety_draft_marks_online_data_optional():
    draft = (
        ROOT
        / "docs"
        / "google-play-data-safety-draft.md"
    ).read_text(
        encoding="utf-8"
    )

    assert "Health info" in draft
    assert "Other user-generated content" in draft
    assert "Optional" in draft
    assert "App functionality" in draft
    assert "do not select at this time" in draft
