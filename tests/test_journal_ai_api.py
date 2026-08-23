from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "journal-ai-test-token"

client = TestClient(app)


@pytest.fixture(autouse=True)
def configure_test_api_token(
    monkeypatch,
):
    monkeypatch.setattr(
        auth_module,
        "RECOVERY_API_TOKEN",
        TEST_API_TOKEN,
    )


def auth_headers() -> dict[str, str]:
    return {
        "Authorization": (
            f"Bearer {TEST_API_TOKEN}"
        ),
    }


@patch("app.api.analyze_journal_entry")
@patch("app.api.load_entries")
def test_journal_ai_analyzes_only_selected_entry(
    mock_load_entries,
    mock_analyze_journal_entry,
):
    mock_load_entries.return_value = [
        {
            "id": 1,
            "text": "First private journal entry.",
            "tags": ["first"],
        },
        {
            "id": 2,
            "text": "I called my sponsor today.",
            "tags": ["connection"],
        },
    ]

    mock_analyze_journal_entry.return_value = (
        "You described choosing connection."
    )

    response = client.post(
        "/journal/2/ai-reflection",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json() == {
        "entry_id": 2,
        "reflection": (
            "You described choosing connection."
        ),
    }

    mock_analyze_journal_entry.assert_called_once_with(
        "I called my sponsor today."
    )


def test_journal_ai_requires_authentication():
    response = client.post(
        "/journal/1/ai-reflection",
    )

    assert response.status_code == 401


@patch("app.api.load_entries")
def test_journal_ai_returns_404_for_missing_entry(
    mock_load_entries,
):
    mock_load_entries.return_value = [
        {
            "id": 1,
            "text": "Existing entry.",
            "tags": [],
        },
    ]

    response = client.post(
        "/journal/999/ai-reflection",
        headers=auth_headers(),
    )

    assert response.status_code == 404
    assert response.json() == {
        "detail": "Journal entry not found.",
    }


@patch("app.api.load_entries")
def test_journal_ai_rejects_blank_entry(
    mock_load_entries,
):
    mock_load_entries.return_value = [
        {
            "id": 1,
            "text": "   ",
            "tags": [],
        },
    ]

    response = client.post(
        "/journal/1/ai-reflection",
        headers=auth_headers(),
    )

    assert response.status_code == 400


@patch("app.api.analyze_journal_entry")
@patch("app.api.load_entries")
def test_journal_ai_does_not_expose_ai_errors(
    mock_load_entries,
    mock_analyze_journal_entry,
):
    mock_load_entries.return_value = [
        {
            "id": 1,
            "text": "Analyze this entry.",
            "tags": [],
        },
    ]

    mock_analyze_journal_entry.side_effect = RuntimeError(
        "Provider failed with secret sk-do-not-expose"
    )

    response = client.post(
        "/journal/1/ai-reflection",
        headers=auth_headers(),
    )

    assert response.status_code == 502
    assert response.json() == {
        "detail": (
            "Unable to generate journal reflection."
        ),
    }

    assert "sk-do-not-expose" not in response.text
