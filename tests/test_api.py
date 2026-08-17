from unittest.mock import patch

from fastapi.testclient import TestClient

from app.api import app
from app.version import __version__


client = TestClient(app)


def test_health_endpoint():
    response = client.get("/health")

    assert response.status_code == 200

    assert response.json() == {
        "status": "ok",
        "version": __version__,
    }


@patch(
    "app.api.build_recovery_insights"
)
def test_recovery_insights_endpoint(
    mock_build_recovery_insights,
):
    mock_build_recovery_insights.return_value = (
        "Recovery Insights Test"
    )

    response = client.get(
        "/recovery-insights"
    )

    assert response.status_code == 200

    assert response.json() == {
        "recovery_insights": (
            "Recovery Insights Test"
        ),
    }

@patch("app.api.get_active_goals")
def test_goals_endpoint(
    mock_get_active_goals,
):
    mock_get_active_goals.return_value = [
        {
            "id": 1,
            "text": "Attend meeting",
            "area": "meetings",
            "status": "active",
        }
    ]

    response = client.get("/goals")

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


@patch("app.api.get_active_routines")
def test_routines_endpoint(
    mock_get_active_routines,
):
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

    response = client.get("/routines")

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