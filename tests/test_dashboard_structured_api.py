from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "dashboard-structured-test-token"

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


@patch("app.api.get_dashboard_data")
@patch("app.api.build_dashboard")
def test_dashboard_returns_text_and_structured_data(
    mock_build_dashboard,
    mock_get_dashboard_data,
):
    mock_build_dashboard.return_value = (
        "Daily Recovery Dashboard"
    )

    mock_get_dashboard_data.return_value = {
        "sobriety_date": "2025-08-12",
        "sobriety_days": 378,
        "today_checkin": {
            "saved": True,
            "completed_count": 4,
            "total": 6,
            "note": "Stayed connected.",
        },
        "current_step": 8,
        "open_assignments": [
            {
                "id": 7,
                "text": "Review inventory.",
            },
        ],
        "latest_journal_entry": {
            "id": 9,
            "created_at": "2026-08-23T18:53:23",
            "text": "Recovery reflection.",
        },
        "recommended_contacts": [
            {
                "id": 2,
                "handle": "SponsorBob",
                "contact_type": "sponsor",
                "contact_method": "555-0100",
                "notes": "Call when isolating.",
                "active": True,
            },
        ],
        "generated_at": "2026-08-23T21:30:00",
    }

    response = client.get(
        "/dashboard",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    body = response.json()

    assert body["dashboard"] == (
        "Daily Recovery Dashboard"
    )

    data = body["dashboard_data"]

    assert data["sobriety_days"] == 378
    assert data["current_step"] == 8
    assert (
        data["today_checkin"]["completed_count"]
        == 4
    )
    assert (
        data["recommended_contacts"][0]["handle"]
        == "SponsorBob"
    )
    assert (
        data["recommended_contacts"][0][
            "contact_method"
        ]
        == "555-0100"
    )


def test_dashboard_structured_data_requires_authentication():
    response = client.get(
        "/dashboard",
    )

    assert response.status_code == 401
