from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app
from app.version import __version__


TEST_API_TOKEN = "recovery-companion-test-token"

client = TestClient(app)


# ============================================================
# Test configuration
# ============================================================

@pytest.fixture(autouse=True)
def configure_test_api_token(
    monkeypatch,
):
    """
    Give every API test a deterministic test-only API token.

    Tests must not depend on the developer's .env file or real
    credentials, which also keeps them portable to GitHub Actions.
    """

    monkeypatch.setattr(
        auth_module,
        "RECOVERY_API_TOKEN",
        TEST_API_TOKEN,
    )


def auth_headers() -> dict[str, str]:
    """Return valid test authorization headers."""

    return {
        "Authorization": (
            f"Bearer {TEST_API_TOKEN}"
        ),
    }


# ============================================================
# Public endpoint
# ============================================================

def test_health_endpoint():
    """The health endpoint should remain public."""

    response = client.get(
        "/health"
    )

    assert response.status_code == 200

    assert response.json() == {
        "status": "ok",
        "version": __version__,
    }


# ============================================================
# Protected recovery-data endpoints
# ============================================================

@patch(
    "app.api.build_recovery_insights"
)
def test_recovery_insights_endpoint(
    mock_build_recovery_insights,
):
    """Authenticated requests should receive Recovery Insights."""

    mock_build_recovery_insights.return_value = (
        "Recovery Insights Test"
    )

    response = client.get(
        "/recovery-insights",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    assert response.json() == {
        "recovery_insights": (
            "Recovery Insights Test"
        ),
    }


@patch(
    "app.api.get_active_goals"
)
def test_goals_endpoint(
    mock_get_active_goals,
):
    """Authenticated requests should receive active goals."""

    mock_get_active_goals.return_value = [
        {
            "id": 1,
            "text": "Attend meeting",
            "area": "meetings",
            "status": "active",
        }
    ]

    response = client.get(
        "/goals",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    assert response.json() == {
        "count": 1,
        "goals": [
            {
                "id": 1,
                "text": "Attend meeting",
                "area": "meetings",
                "status": "active",
            }
        ],
    }


@patch(
    "app.api.get_active_routines"
)
def test_routines_endpoint(
    mock_get_active_routines,
):
    """Authenticated requests should receive active routines."""

    mock_get_active_routines.return_value = [
        {
            "id": 1,
            "text": "Morning prayer",
            "area": "prayer",
            "frequency": "daily",
            "day_of_week": "",
            "active": True,
        }
    ]

    response = client.get(
        "/routines",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    assert response.json() == {
        "count": 1,
        "routines": [
            {
                "id": 1,
                "text": "Morning prayer",
                "area": "prayer",
                "frequency": "daily",
                "day_of_week": "",
                "active": True,
            }
        ],
    }


# ============================================================
# Authentication behavior
# ============================================================

def test_protected_endpoint_requires_token():
    """Protected endpoints should reject requests without a token."""

    response = client.get(
        "/goals"
    )

    assert response.status_code == 401

    assert response.json() == {
        "detail": "Invalid or missing API token.",
    }


def test_protected_endpoint_rejects_wrong_token():
    """Protected endpoints should reject an invalid Bearer token."""

    response = client.get(
        "/goals",
        headers={
            "Authorization": "Bearer wrong-token",
        },
    )

    assert response.status_code == 401

    assert response.json() == {
        "detail": "Invalid or missing API token.",
    }


@patch(
    "app.api.get_active_goals"
)
def test_goals_endpoint_with_auth(
    mock_get_active_goals,
):
    """A valid test token should authorize access to goals."""

    mock_get_active_goals.return_value = [
        {
            "id": 1,
            "text": "Attend meeting",
            "area": "meetings",
            "status": "active",
        }
    ]

    response = client.get(
        "/goals",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["count"] == 1


@patch(
    "app.api.get_active_routines"
)
def test_routines_endpoint_with_auth(
    mock_get_active_routines,
):
    """A valid test token should authorize access to routines."""

    mock_get_active_routines.return_value = [
        {
            "id": 1,
            "text": "Morning prayer",
            "area": "prayer",
            "frequency": "daily",
            "day_of_week": "",
            "active": True,
        }
    ]

    response = client.get(
        "/routines",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["count"] == 1


# ============================================================
# Synchronization endpoint
# ============================================================

@patch(
    "app.api.build_sync_payload"
)
def test_sync_endpoint_with_auth(
    mock_build_sync_payload,
):
    """Authenticated requests should receive synchronization data."""

    mock_build_sync_payload.return_value = {
        "sync_schema_version": 1,
        "data": {
            "profile": {},
        },
    }

    response = client.get(
        "/sync",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert (
        response.json()["sync_schema_version"]
        == 1
    )


def test_sync_endpoint_requires_token():
    """The synchronization endpoint must require authentication."""

    response = client.get(
        "/sync"
    )

    assert response.status_code == 401

@patch("app.api.get_checkin_for_date")
def test_today_checkin_endpoint_with_auth(
    mock_get_checkin_for_date,
):
    mock_get_checkin_for_date.return_value = {
        "date": "2026-08-19",
        "prayer_meditation": True,
        "recovery_contact": False,
        "meeting": True,
        "step_work": False,
        "journal": True,
        "service": False,
        "note": "Test note",
    }

    response = client.get(
        "/daily-checkin/today",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["checkin"]["meeting"] is True


@patch("app.api.save_daily_checkin")
def test_update_today_checkin_with_auth(
    mock_save_daily_checkin,
):
    mock_save_daily_checkin.return_value = {
        "date": "2026-08-19",
        "prayer_meditation": True,
        "recovery_contact": True,
        "meeting": False,
        "step_work": True,
        "journal": True,
        "service": False,
        "note": "Stayed connected.",
    }

    response = client.put(
        "/daily-checkin/today",
        headers=auth_headers(),
        json={
            "prayer_meditation": True,
            "recovery_contact": True,
            "meeting": False,
            "step_work": True,
            "journal": True,
            "service": False,
            "note": "Stayed connected.",
        },
    )

    assert response.status_code == 200

    result = response.json()["checkin"]

    assert result["recovery_contact"] is True
    assert result["step_work"] is True
    assert result["note"] == "Stayed connected."


def test_today_checkin_endpoint_requires_token():
    response = client.get(
        "/daily-checkin/today"
    )

    assert response.status_code == 401


def test_update_today_checkin_requires_token():
    response = client.put(
        "/daily-checkin/today",
        json={},
    )

    assert response.status_code == 401