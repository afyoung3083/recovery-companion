from unittest.mock import patch

from app.goals import (
    add_goal,
    complete_goal,
    format_goals,
    get_active_goals,
    reactivate_goal,
)


@patch("app.goals.save_goals")
@patch("app.goals.load_goals")
def test_add_goal_creates_active_goal(
    mock_load_goals,
    mock_save_goals,
):
    mock_load_goals.return_value = []

    goal = add_goal(
        text="Attend 90 meetings in 90 days.",
        area="meetings",
        target_date="2026-11-14",
    )

    assert goal["id"] == 1
    assert goal["status"] == "active"
    assert goal["area"] == "meetings"
    assert goal["target_date"] == "2026-11-14"

    mock_save_goals.assert_called_once()


@patch("app.goals.save_goals")
@patch("app.goals.load_goals")
def test_complete_goal_marks_goal_completed(
    mock_load_goals,
    mock_save_goals,
):
    mock_load_goals.return_value = [
        {
            "id": 1,
            "text": "Attend meeting",
            "area": "meetings",
            "status": "active",
            "completed_date": "",
        }
    ]

    goal = complete_goal(1)

    assert goal is not None
    assert goal["status"] == "completed"
    assert goal["completed_date"] != ""

    mock_save_goals.assert_called_once()


@patch("app.goals.save_goals")
@patch("app.goals.load_goals")
def test_reactivate_goal_returns_goal_to_active(
    mock_load_goals,
    mock_save_goals,
):
    mock_load_goals.return_value = [
        {
            "id": 1,
            "text": "Attend meeting",
            "area": "meetings",
            "status": "completed",
            "completed_date": "2026-08-15",
        }
    ]

    goal = reactivate_goal(1)

    assert goal is not None
    assert goal["status"] == "active"
    assert goal["completed_date"] == ""

    mock_save_goals.assert_called_once()


@patch("app.goals.load_goals")
def test_get_active_goals_excludes_completed(
    mock_load_goals,
):
    mock_load_goals.return_value = [
        {
            "id": 1,
            "status": "active",
        },
        {
            "id": 2,
            "status": "completed",
        },
    ]

    goals = get_active_goals()

    assert len(goals) == 1
    assert goals[0]["id"] == 1


def test_format_goals_handles_empty_list():
    assert (
        format_goals([])
        == "No recovery goals saved."
    )