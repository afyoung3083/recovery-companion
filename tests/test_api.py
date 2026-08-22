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

@patch("app.api.load_entries")
def test_journal_endpoint_with_auth(
    mock_load_entries,
):
    mock_load_entries.return_value = [
        {
            "id": 1,
            "date": "2026-08-19",
            "text": "Stayed connected today.",
            "tags": ["connection"],
        }
    ]

    response = client.get(
        "/journal",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    result = response.json()

    assert result["count"] == 1
    assert result["entries"][0]["id"] == 1


@patch("app.api.add_entry")
def test_create_journal_entry_with_auth(
    mock_add_entry,
):
    mock_add_entry.return_value = {
        "id": 2,
        "date": "2026-08-19",
        "text": "Called my sponsor.",
        "tags": ["connection", "sponsor"],
    }

    response = client.post(
        "/journal",
        headers=auth_headers(),
        json={
            "text": "Called my sponsor.",
            "tags": [
                "connection",
                "sponsor",
            ],
        },
    )

    assert response.status_code == 200

    result = response.json()["entry"]

    assert result["id"] == 2
    assert result["text"] == "Called my sponsor."


@patch("app.api.search_entries")
@patch("app.api.load_entries")
def test_search_journal_entries_with_auth(
    mock_load_entries,
    mock_search_entries,
):
    mock_load_entries.return_value = [
        {
            "id": 1,
            "text": "Meeting with sponsor.",
            "tags": ["sponsor"],
        }
    ]

    mock_search_entries.return_value = [
        {
            "id": 1,
            "text": "Meeting with sponsor.",
            "tags": ["sponsor"],
        }
    ]

    response = client.get(
        "/journal/search?q=sponsor",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    result = response.json()

    assert result["count"] == 1
    assert result["entries"][0]["text"] == "Meeting with sponsor."


def test_journal_endpoint_requires_token():
    response = client.get(
        "/journal"
    )

    assert response.status_code == 401


def test_create_journal_entry_requires_token():
    response = client.post(
        "/journal",
        json={
            "text": "Test",
            "tags": [],
        },
    )

    assert response.status_code == 401

@patch("app.api.load_step_work")
def test_step_work_endpoint_with_auth(
    mock_load_step_work,
):
    mock_load_step_work.return_value = {
        "current_step": 4,
        "assignments": [
            {
                "id": 1,
                "step": 4,
                "text": "Write resentment inventory.",
                "completed": False,
            }
        ],
        "notes": [],
    }

    response = client.get(
        "/step-work",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["step_work"]["current_step"] == 4


@patch("app.api.set_current_step")
def test_update_current_step_with_auth(
    mock_set_current_step,
):
    mock_set_current_step.return_value = {
        "current_step": 5,
        "assignments": [],
        "notes": [],
    }

    response = client.put(
        "/step-work/current-step",
        headers=auth_headers(),
        json={
            "step_number": 5,
        },
    )

    assert response.status_code == 200
    assert response.json()["step_work"]["current_step"] == 5


@patch("app.api.add_assignment")
def test_create_step_assignment_with_auth(
    mock_add_assignment,
):
    mock_add_assignment.return_value = {
        "id": 2,
        "step": 4,
        "text": "Call sponsor.",
        "completed": False,
    }

    response = client.post(
        "/step-work/assignments",
        headers=auth_headers(),
        json={
            "text": "Call sponsor.",
        },
    )

    assert response.status_code == 200
    assert response.json()["assignment"]["id"] == 2


@patch("app.api.complete_assignment")
def test_complete_step_assignment_with_auth(
    mock_complete_assignment,
):
    mock_complete_assignment.return_value = {
        "id": 2,
        "step": 4,
        "text": "Call sponsor.",
        "completed": True,
    }

    response = client.put(
        "/step-work/assignments/2/complete",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["assignment"]["completed"] is True


@patch("app.api.complete_assignment")
def test_complete_step_assignment_returns_404_when_missing(
    mock_complete_assignment,
):
    mock_complete_assignment.return_value = None

    response = client.put(
        "/step-work/assignments/999/complete",
        headers=auth_headers(),
    )

    assert response.status_code == 404


def test_step_work_endpoint_requires_token():
    response = client.get(
        "/step-work"
    )

    assert response.status_code == 401

@patch("app.api.load_contacts")
def test_fellowship_endpoint_with_auth(
    mock_load_contacts,
):
    mock_load_contacts.return_value = [
        {
            "id": 1,
            "handle": "Mike",
            "contact_type": "sponsor",
            "contact_method": "555-0100",
            "notes": "",
            "active": True,
        }
    ]

    response = client.get(
        "/fellowship",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["count"] == 1
    assert response.json()["contacts"][0]["handle"] == "Mike"


@patch("app.api.add_contact")
def test_create_fellowship_contact_with_auth(
    mock_add_contact,
):
    mock_add_contact.return_value = {
        "id": 2,
        "handle": "John",
        "contact_type": "fellowship",
        "contact_method": "555-0200",
        "notes": "Thursday meeting",
        "active": True,
    }

    response = client.post(
        "/fellowship",
        headers=auth_headers(),
        json={
            "handle": "John",
            "contact_type": "fellowship",
            "contact_method": "555-0200",
            "notes": "Thursday meeting",
        },
    )

    assert response.status_code == 200
    assert response.json()["contact"]["id"] == 2


@patch("app.api.set_contact_active")
def test_update_fellowship_contact_active_with_auth(
    mock_set_contact_active,
):
    mock_set_contact_active.return_value = {
        "id": 2,
        "handle": "John",
        "contact_type": "fellowship",
        "active": False,
    }

    response = client.put(
        "/fellowship/2/active",
        headers=auth_headers(),
        json={
            "active": False,
        },
    )

    assert response.status_code == 200
    assert response.json()["contact"]["active"] is False


@patch("app.api.set_contact_active")
def test_update_fellowship_contact_returns_404_when_missing(
    mock_set_contact_active,
):
    mock_set_contact_active.return_value = None

    response = client.put(
        "/fellowship/999/active",
        headers=auth_headers(),
        json={
            "active": False,
        },
    )

    assert response.status_code == 404


@patch("app.api.recommend_contacts")
@patch("app.api.load_contacts")
def test_recommended_fellowship_contacts_with_auth(
    mock_load_contacts,
    mock_recommend_contacts,
):
    contacts = [
        {
            "id": 1,
            "handle": "Mike",
            "contact_type": "sponsor",
            "active": True,
        }
    ]

    mock_load_contacts.return_value = contacts
    mock_recommend_contacts.return_value = contacts

    response = client.get(
        "/fellowship/recommended?limit=3",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["count"] == 1
    assert response.json()["contacts"][0]["handle"] == "Mike"


def test_fellowship_endpoint_requires_token():
    response = client.get(
        "/fellowship"
    )

    assert response.status_code == 401

@patch("app.api.add_goal")
def test_create_goal_with_auth(
    mock_add_goal,
):
    mock_add_goal.return_value = {
        "id": 2,
        "text": "Attend three meetings this week.",
        "area": "meetings",
        "target_date": "2026-08-31",
        "status": "active",
    }

    response = client.post(
        "/goals",
        headers=auth_headers(),
        json={
            "text": "Attend three meetings this week.",
            "area": "meetings",
            "target_date": "2026-08-31",
        },
    )

    assert response.status_code == 200
    assert response.json()["goal"]["id"] == 2


@patch("app.api.add_goal")
def test_create_goal_returns_400_for_invalid_input(
    mock_add_goal,
):
    mock_add_goal.side_effect = ValueError(
        "Invalid recovery area."
    )

    response = client.post(
        "/goals",
        headers=auth_headers(),
        json={
            "text": "Test goal",
            "area": "invalid",
            "target_date": "",
        },
    )

    assert response.status_code == 400


@patch("app.api.complete_goal")
def test_complete_goal_with_auth(
    mock_complete_goal,
):
    mock_complete_goal.return_value = {
        "id": 2,
        "text": "Attend three meetings this week.",
        "status": "completed",
    }

    response = client.put(
        "/goals/2/complete",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["goal"]["status"] == "completed"


@patch("app.api.reactivate_goal")
def test_reactivate_goal_with_auth(
    mock_reactivate_goal,
):
    mock_reactivate_goal.return_value = {
        "id": 2,
        "text": "Attend three meetings this week.",
        "status": "active",
    }

    response = client.put(
        "/goals/2/reactivate",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json()["goal"]["status"] == "active"


@patch("app.api.add_routine")
def test_create_routine_with_auth(
    mock_add_routine,
):
    mock_add_routine.return_value = {
        "id": 3,
        "text": "Call sponsor every Friday.",
        "area": "connection",
        "frequency": "weekly",
        "day_of_week": "friday",
        "active": True,
    }

    response = client.post(
        "/routines",
        headers=auth_headers(),
        json={
            "text": "Call sponsor every Friday.",
            "area": "connection",
            "frequency": "weekly",
            "day_of_week": "friday",
        },
    )

    assert response.status_code == 200
    assert response.json()["routine"]["id"] == 3


@patch("app.api.add_routine")
def test_create_routine_returns_400_for_invalid_input(
    mock_add_routine,
):
    mock_add_routine.side_effect = ValueError(
        "Frequency must be daily or weekly."
    )

    response = client.post(
        "/routines",
        headers=auth_headers(),
        json={
            "text": "Test routine",
            "area": "connection",
            "frequency": "monthly",
            "day_of_week": "",
        },
    )

    assert response.status_code == 400


@patch("app.api.set_routine_active")
def test_update_routine_active_with_auth(
    mock_set_routine_active,
):
    mock_set_routine_active.return_value = {
        "id": 3,
        "text": "Call sponsor every Friday.",
        "active": False,
    }

    response = client.put(
        "/routines/3/active",
        headers=auth_headers(),
        json={
            "active": False,
        },
    )

    assert response.status_code == 200
    assert response.json()["routine"]["active"] is False