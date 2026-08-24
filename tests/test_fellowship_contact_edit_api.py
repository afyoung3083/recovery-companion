from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app
from app.fellowship import update_contact


TEST_API_TOKEN = "fellowship-edit-test-token"

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


def test_update_contact_preserves_id_and_active():
    contacts = [
        {
            "id": 3,
            "handle": "Old Name",
            "contact_type": "fellowship",
            "contact_method": "old@example.test",
            "notes": "Old notes",
            "active": False,
        },
    ]

    with (
        patch(
            "app.fellowship.load_contacts",
            return_value=contacts,
        ),
        patch(
            "app.fellowship.save_contacts",
        ) as mock_save,
    ):
        result = update_contact(
            contact_id=3,
            handle=" Sponsor Bob ",
            contact_type="SPONSOR",
            contact_method=" 555-0100 ",
            notes=" Call when isolating. ",
        )

    assert result == {
        "id": 3,
        "handle": "Sponsor Bob",
        "contact_type": "sponsor",
        "contact_method": "555-0100",
        "notes": "Call when isolating.",
        "active": False,
    }

    mock_save.assert_called_once_with(
        contacts
    )


@patch("app.api.update_contact")
def test_update_fellowship_contact_endpoint(
    mock_update_contact,
):
    mock_update_contact.return_value = {
        "id": 3,
        "handle": "Sponsor Bob",
        "contact_type": "sponsor",
        "contact_method": "555-0100",
        "notes": "Call when isolating.",
        "active": True,
    }

    response = client.put(
        "/fellowship/3",
        headers=auth_headers(),
        json={
            "handle": "Sponsor Bob",
            "contact_type": "sponsor",
            "contact_method": "555-0100",
            "notes": "Call when isolating.",
        },
    )

    assert response.status_code == 200

    assert response.json()["contact"][
        "handle"
    ] == "Sponsor Bob"

    mock_update_contact.assert_called_once_with(
        contact_id=3,
        handle="Sponsor Bob",
        contact_type="sponsor",
        contact_method="555-0100",
        notes="Call when isolating.",
    )


@patch("app.api.update_contact")
def test_update_missing_fellowship_contact_returns_404(
    mock_update_contact,
):
    mock_update_contact.return_value = None

    response = client.put(
        "/fellowship/999",
        headers=auth_headers(),
        json={
            "handle": "Missing",
            "contact_type": "other",
            "contact_method": "",
            "notes": "",
        },
    )

    assert response.status_code == 404
