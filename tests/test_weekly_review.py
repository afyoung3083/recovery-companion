from unittest.mock import patch

from app.weekly_review import build_weekly_review


@patch("app.weekly_review.load_step_work")
@patch("app.weekly_review.get_recent_journal_entries_for_week")
@patch("app.weekly_review.get_recent_checkins_for_week")
def test_build_weekly_review_summarizes_recovery_data(
    mock_checkins,
    mock_journal,
    mock_step_work,
):
    mock_checkins.return_value = [
        {
            "prayer_meditation": True,
            "recovery_contact": True,
            "meeting": False,
            "step_work": True,
            "journal": False,
            "service": False,
            "note": "Stayed connected.",
        },
        {
            "prayer_meditation": True,
            "recovery_contact": True,
            "meeting": True,
            "step_work": False,
            "journal": True,
            "service": True,
            "note": "Good meeting.",
        },
    ]

    mock_journal.return_value = [{}, {}]

    mock_step_work.return_value = {
        "current_step": 1,
        "assignments": [
            {
                "id": 3,
                "step": 1,
                "text": "Write about unmanageability.",
                "completed": False,
            }
        ],
    }

    result = build_weekly_review()

    assert "Check-In Days: 2/7" in result
    assert "Prayer / meditation: 2/2" in result
    assert "Meeting: 1/2" in result
    assert "Journal Entries This Week: 2" in result
    assert "Current Step: 1" in result
    assert "[3] Write about unmanageability." in result
    assert "Stayed connected." in result
    assert "Good meeting." in result


@patch("app.weekly_review.load_step_work")
@patch("app.weekly_review.get_recent_journal_entries_for_week")
@patch("app.weekly_review.get_recent_checkins_for_week")
def test_build_weekly_review_handles_empty_week(
    mock_checkins,
    mock_journal,
    mock_step_work,
):
    mock_checkins.return_value = []
    mock_journal.return_value = []
    mock_step_work.return_value = {
        "current_step": 1,
        "assignments": [],
    }

    result = build_weekly_review()

    assert "Check-In Days: 0/7" in result
    assert "Journal Entries This Week: 0" in result
    assert "Open Step Assignments:\n  None" in result
    assert "Recent Check-In Notes:\n  None" in result