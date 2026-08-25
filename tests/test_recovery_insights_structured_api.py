from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "insights-structured-test-token"

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


@patch("app.api.get_recovery_insights_data")
@patch("app.api.build_recovery_insights")
def test_recovery_insights_returns_text_and_structured_data(
    mock_build_insights,
    mock_get_insights_data,
):
    mock_build_insights.return_value = (
        "Recovery Insights"
    )

    mock_get_insights_data.return_value = {
        "sobriety_date": "2025-08-10",
        "sobriety_days": 378,
        "current_step": 8,
        "open_step_assignments": 0,
        "active_recovery_goals": 2,
        "checkin_days_available": 5,
        "checkin_window_days": 7,
        "latest_weekly_snapshot": {
            "week_start": "2026-08-17",
            "week_end": "2026-08-23",
            "checkin_days": 5,
            "journal_entries": 3,
        },
        "latest_monthly_snapshot": {
            "snapshot_date": "2026-08-23",
            "period_start": "2026-07-27",
            "period_end": "2026-08-23",
            "weekly_reviews_included": 4,
            "checkin_days": 20,
            "journal_entries": 10,
        },
    }

    response = client.get(
        "/recovery-insights",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    body = response.json()

    assert body["recovery_insights"] == (
        "Recovery Insights"
    )

    data = body["recovery_insights_data"]

    assert data["sobriety_days"] == 378
    assert data["current_step"] == 8
    assert data["active_recovery_goals"] == 2
    assert data["checkin_days_available"] == 5
    assert (
        data["latest_weekly_snapshot"][
            "journal_entries"
        ]
        == 3
    )


def test_structured_recovery_insights_requires_authentication():
    response = client.get(
        "/recovery-insights",
    )

    assert response.status_code == 401
