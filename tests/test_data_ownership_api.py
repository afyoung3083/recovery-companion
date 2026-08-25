from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "data-ownership-test-token"

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
        "Authorization": (
            f"Bearer {TEST_API_TOKEN}"
        ),
    }


@patch("app.api.build_backup_payload")
def test_data_export_returns_complete_backup_payload(
    mock_build_backup_payload,
):
    export_payload = {
        "metadata": {
            "backup_format_version": 1,
            "created_at": "2026-08-25T07:55:00",
            "sha256": "example-integrity-hash",
        },
        "profile": {
            "sobriety_date": "2025-08-12",
        },
        "journal_entries": [
            {
                "id": 1,
                "text": "Recovery reflection.",
            },
        ],
        "step_work": {
            "current_step": 8,
            "assignments": [],
            "notes": [],
        },
        "fellowship_contacts": [],
        "daily_checkins": [],
        "weekly_reviews": [],
        "monthly_reviews": [],
        "goals": [],
        "routines": [],
    }

    mock_build_backup_payload.return_value = (
        export_payload
    )

    response = client.get(
        "/data-ownership/export",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json() == {
        "export": export_payload,
    }

    mock_build_backup_payload.assert_called_once_with()


def test_data_export_requires_authentication():
    response = client.get(
        "/data-ownership/export",
    )

    assert response.status_code == 401
