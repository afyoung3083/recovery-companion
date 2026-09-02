from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
import app.step_work as step_work_module
from app.api import app


TEST_API_TOKEN = "step-work-edit-token"

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


def configure_step_work_file(
    monkeypatch,
    tmp_path,
):
    path = tmp_path / "step_work.json"

    monkeypatch.setattr(
        step_work_module,
        "STEP_WORK_FILE",
        path,
    )

    monkeypatch.setattr(
        step_work_module,
        "ensure_data_directory",
        lambda: tmp_path.mkdir(
            parents=True,
            exist_ok=True,
        ),
    )

    step_work_module.save_step_work(
        {
            "current_step": 8,
            "assignments": [
                {
                    "id": 3,
                    "step": 8,
                    "text": "Mispelled assignment",
                    "completed": False,
                    "completed_at": None,
                },
            ],
            "notes": [],
        }
    )


def test_storage_edits_step_assignment(
    monkeypatch,
    tmp_path,
):
    configure_step_work_file(
        monkeypatch,
        tmp_path,
    )

    updated = step_work_module.update_assignment(
        assignment_id=3,
        text="Corrected assignment",
    )

    assert updated is not None
    assert updated["text"] == "Corrected assignment"
    assert updated["updated_at"]

    stored = step_work_module.load_step_work()

    assert (
        stored["assignments"][0]["text"]
        == "Corrected assignment"
    )


def test_storage_can_reopen_step_assignment(
    monkeypatch,
    tmp_path,
):
    configure_step_work_file(
        monkeypatch,
        tmp_path,
    )

    completed = (
        step_work_module.set_assignment_completed(
            assignment_id=3,
            completed=True,
        )
    )

    assert completed is not None
    assert completed["completed"] is True
    assert completed["completed_at"] is not None

    reopened = (
        step_work_module.set_assignment_completed(
            assignment_id=3,
            completed=False,
        )
    )

    assert reopened is not None
    assert reopened["completed"] is False
    assert reopened["completed_at"] is None


@patch("app.api.update_assignment")
def test_api_edits_step_assignment(
    mock_update_assignment,
):
    mock_update_assignment.return_value = {
        "id": 3,
        "step": 8,
        "text": "Corrected assignment",
        "completed": False,
    }

    response = client.put(
        "/step-work/assignments/3",
        headers=auth_headers(),
        json={
            "text": "Corrected assignment",
        },
    )

    assert response.status_code == 200

    assert (
        response.json()["assignment"]["text"]
        == "Corrected assignment"
    )

    mock_update_assignment.assert_called_once_with(
        assignment_id=3,
        text="Corrected assignment",
    )


@patch("app.api.set_assignment_completed")
def test_api_can_reopen_step_assignment(
    mock_set_assignment_completed,
):
    mock_set_assignment_completed.return_value = {
        "id": 3,
        "step": 8,
        "text": "Assignment",
        "completed": False,
        "completed_at": None,
    }

    response = client.put(
        "/step-work/assignments/3/completed",
        headers=auth_headers(),
        json={
            "completed": False,
        },
    )

    assert response.status_code == 200

    assert (
        response.json()["assignment"]["completed"]
        is False
    )

    mock_set_assignment_completed.assert_called_once_with(
        assignment_id=3,
        completed=False,
    )
