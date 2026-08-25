from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "dashboard-profile-test-token"

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


@patch("app.api.get_dashboard_data")
@patch("app.api.build_dashboard")
def test_dashboard_returns_local_summary(
    mock_build_dashboard,
    mock_get_dashboard_data,
):
    mock_build_dashboard.return_value = (
        "Daily Recovery Dashboard\nSobriety: 12 day(s)"
    )

    mock_get_dashboard_data.return_value = {
        "sobriety_days": 12,
    }

    response = client.get(
        "/dashboard",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    body = response.json()

    assert body["dashboard"] == (
        "Daily Recovery Dashboard\n"
        "Sobriety: 12 day(s)"
    )

    assert body["dashboard_data"] == {
        "sobriety_days": 12,
    }

    mock_build_dashboard.assert_called_once_with()
    mock_get_dashboard_data.assert_called_once_with()


def test_dashboard_requires_authentication():
    response = client.get(
        "/dashboard",
    )

    assert response.status_code == 401


@patch("app.api.load_profile")
def test_profile_returns_local_profile(
    mock_load_profile,
):
    mock_load_profile.return_value = {
        "sobriety_date": "2026-08-12",
    }

    response = client.get(
        "/profile",
        headers=auth_headers(),
    )

    assert response.status_code == 200
    assert response.json() == {
        "profile": {
            "sobriety_date": "2026-08-12",
        },
    }


@patch("app.api.set_sobriety_date")
def test_profile_updates_valid_sobriety_date(
    mock_set_sobriety_date,
):
    mock_set_sobriety_date.return_value = {
        "sobriety_date": "2026-08-12",
    }

    response = client.put(
        "/profile/sobriety-date",
        headers=auth_headers(),
        json={
            "sobriety_date": "2026-08-12",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "profile": {
            "sobriety_date": "2026-08-12",
        },
    }

    mock_set_sobriety_date.assert_called_once_with(
        "2026-08-12"
    )


@patch("app.api.set_sobriety_date")
def test_profile_rejects_invalid_date(
    mock_set_sobriety_date,
):
    response = client.put(
        "/profile/sobriety-date",
        headers=auth_headers(),
        json={
            "sobriety_date": "08/12/2026",
        },
    )

    assert response.status_code == 400
    assert response.json() == {
        "detail": (
            "Sobriety date must use YYYY-MM-DD format."
        ),
    }

    mock_set_sobriety_date.assert_not_called()


@patch("app.api.set_sobriety_date")
def test_profile_rejects_future_date(
    mock_set_sobriety_date,
):
    response = client.put(
        "/profile/sobriety-date",
        headers=auth_headers(),
        json={
            "sobriety_date": "2999-01-01",
        },
    )

    assert response.status_code == 400
    assert response.json() == {
        "detail": (
            "Sobriety date cannot be in the future."
        ),
    }

    mock_set_sobriety_date.assert_not_called()


def test_profile_requires_authentication():
    response = client.get(
        "/profile",
    )

    assert response.status_code == 401

    response = client.put(
        "/profile/sobriety-date",
        json={
            "sobriety_date": "2026-08-12",
        },
    )

    assert response.status_code == 401
