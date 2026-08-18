from unittest.mock import patch

from fastapi.testclient import TestClient

from app.api import app
from app.config import RECOVERY_API_TOKEN
from app.version import __version__


client = TestClient(app)


# ============================================================
# Test helpers
# ============================================================

def auth_headers() -> dict[str, str]:
    """Return valid authorization headers for protected API tests."""

    return {
        "Authorization": f"Bearer {RECOVERY_API_TOKEN}",
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
    """A valid token should authorize access to goals."""

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
    """A valid token should authorize access to routines."""

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

@patch("app.api.build_sync_payload")
def test_sync_endpoint_with_auth(
    mock_build_sync_payload,
):
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
    assert response.json()["sync_schema_version"] == 1


def test_sync_endpoint_requires_token():
    response = client.get("/sync")

    assert response.status_code == 401