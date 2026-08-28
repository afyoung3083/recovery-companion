from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "journal-local-ai-token"

client = TestClient(app)


@pytest.fixture(autouse=True)
def configure_test_api_token(monkeypatch):
    monkeypatch.setattr(
        auth_module,
        "RECOVERY_API_TOKEN",
        TEST_API_TOKEN,
    )


def auth_headers() -> dict[str, str]:
    return {
        "Authorization": f"Bearer {TEST_API_TOKEN}",
    }


@patch("app.api.analyze_journal_entry")
@patch("app.api.load_entries")
def test_journal_ai_accepts_explicit_local_entry_text(
    mock_load_entries,
    mock_analyze_journal_entry,
):
    mock_analyze_journal_entry.return_value = (
        "Reflection from explicitly selected local entry."
    )

    response = client.post(
        "/journal/37/ai-reflection",
        headers=auth_headers(),
        json={
            "text": "THIS EXACT LOCAL ENTRY",
        },
    )

    assert response.status_code == 200

    assert response.json() == {
        "entry_id": 37,
        "reflection": (
            "Reflection from explicitly selected local entry."
        ),
    }

    mock_load_entries.assert_not_called()

    mock_analyze_journal_entry.assert_called_once_with(
        "THIS EXACT LOCAL ENTRY"
    )


@patch("app.api.analyze_journal_entry")
def test_journal_ai_rejects_empty_explicit_text(
    mock_analyze_journal_entry,
):
    response = client.post(
        "/journal/37/ai-reflection",
        headers=auth_headers(),
        json={
            "text": "   ",
        },
    )

    assert response.status_code == 400

    mock_analyze_journal_entry.assert_not_called()
