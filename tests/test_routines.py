from unittest.mock import patch

from app.routines import (
    add_routine,
    format_routines,
    get_active_routines,
    set_routine_active,
)


@patch("app.routines.save_routines")
@patch("app.routines.load_routines")
def test_add_daily_routine(
    mock_load_routines,
    mock_save_routines,
):
    mock_load_routines.return_value = []

    routine = add_routine(
        text="Pray in the morning",
        area="prayer",
        frequency="daily",
    )

    assert routine["id"] == 1
    assert routine["frequency"] == "daily"
    assert routine["day_of_week"] == ""
    assert routine["active"] is True

    mock_save_routines.assert_called_once()


@patch("app.routines.save_routines")
@patch("app.routines.load_routines")
def test_add_weekly_routine(
    mock_load_routines,
    mock_save_routines,
):
    mock_load_routines.return_value = []

    routine = add_routine(
        text="Attend Friday meeting",
        area="meetings",
        frequency="weekly",
        day_of_week="Friday",
    )

    assert routine["frequency"] == "weekly"
    assert routine["day_of_week"] == "friday"
    assert routine["active"] is True

    mock_save_routines.assert_called_once()


def test_weekly_routine_requires_valid_day():
    try:
        add_routine(
            text="Attend meeting",
            area="meetings",
            frequency="weekly",
            day_of_week="Funday",
        )
    except ValueError as error:
        assert (
            str(error)
            == "Weekly routines require a valid day of week."
        )
    else:
        raise AssertionError(
            "Expected ValueError for invalid day."
        )


@patch("app.routines.save_routines")
@patch("app.routines.load_routines")
def test_set_routine_active_changes_status(
    mock_load_routines,
    mock_save_routines,
):
    mock_load_routines.return_value = [
        {
            "id": 1,
            "text": "Pray",
            "area": "prayer",
            "frequency": "daily",
            "day_of_week": "",
            "active": True,
        }
    ]

    routine = set_routine_active(
        routine_id=1,
        active=False,
    )

    assert routine is not None
    assert routine["active"] is False

    mock_save_routines.assert_called_once()


@patch("app.routines.load_routines")
def test_get_active_routines_excludes_inactive(
    mock_load_routines,
):
    mock_load_routines.return_value = [
        {
            "id": 1,
            "active": True,
        },
        {
            "id": 2,
            "active": False,
        },
    ]

    routines = get_active_routines()

    assert len(routines) == 1
    assert routines[0]["id"] == 1


def test_format_routines_handles_empty_list():
    assert (
        format_routines([])
        == "No recovery routines saved."
    )