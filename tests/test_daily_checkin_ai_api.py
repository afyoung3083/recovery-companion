from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "checkin-ai-test-token"

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


@patch("app.api.analyze_checkin_trends")
@patch("app.api.format_checkin_trends")
@patch("app.api.format_checkin_history")
@patch("app.api.get_recent_checkins")
def test_checkin_ai_analyzes_only_recent_summary(
    mock_get_recent_checkins,
    mock_format_history,
    mock_format_trends,
    mock_analyze_checkin_trends,
):
    checkins = [
        {
            "date": "2026-08-23",
            "recovery_contact": True,
            "note": "Called my sponsor.",
        },
        {
            "date": "2026-08-22",
            "meeting": True,
            "note": "Went to a meeting.",
        },
    ]

    mock_get_recent_checkins.return_value = (
        checkins
    )

    mock_format_history.return_value = (
        "RECENT CHECK-IN HISTORY"
    )

    mock_format_trends.return_value = (
        "RECENT CHECK-IN TRENDS"
    )

    mock_analyze_checkin_trends.return_value = (
        "Connection has been visible in the recent check-ins."
    )

    response = client.post(
        "/daily-checkin/ai-reflection",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    assert response.json() == {
        "checkin_count": 2,
        "reflection": (
            "Connection has been visible in the recent check-ins."
        ),
    }

    mock_get_recent_checkins.assert_called_once_with(
        limit=7
    )

    mock_format_history.assert_called_once_with(
        checkins
    )

    mock_format_trends.assert_called_once_with(
        checkins
    )

    mock_analyze_checkin_trends.assert_called_once_with(
        "RECENT CHECK-IN HISTORY\n\n"
        "RECENT CHECK-IN TRENDS"
    )


def test_checkin_ai_requires_authentication():
    response = client.post(
        "/daily-checkin/ai-reflection",
    )

    assert response.status_code == 401


@patch("app.api.analyze_checkin_trends")
@patch("app.api.get_recent_checkins")
def test_checkin_ai_returns_404_without_history(
    mock_get_recent_checkins,
    mock_analyze_checkin_trends,
):
    mock_get_recent_checkins.return_value = []

    response = client.post(
        "/daily-checkin/ai-reflection",
        headers=auth_headers(),
    )

    assert response.status_code == 404

    assert response.json() == {
        "detail": (
            "No recent check-ins available to analyze."
        ),
    }

    mock_analyze_checkin_trends.assert_not_called()


@patch("app.api.analyze_checkin_trends")
@patch("app.api.format_checkin_trends")
@patch("app.api.format_checkin_history")
@patch("app.api.get_recent_checkins")
def test_checkin_ai_does_not_expose_ai_errors(
    mock_get_recent_checkins,
    mock_format_history,
    mock_format_trends,
    mock_analyze_checkin_trends,
):
    mock_get_recent_checkins.return_value = [
        {
            "date": "2026-08-23",
            "note": "Private recovery note.",
        },
    ]

    mock_format_history.return_value = "HISTORY"
    mock_format_trends.return_value = "TRENDS"

    mock_analyze_checkin_trends.side_effect = (
        RuntimeError(
            "Provider failed with secret sk-do-not-expose"
        )
    )

    response = client.post(
        "/daily-checkin/ai-reflection",
        headers=auth_headers(),
    )

    assert response.status_code == 502

    assert response.json() == {
        "detail": (
            "Unable to generate check-in reflection."
        ),
    }

    assert "sk-do-not-expose" not in response.text
