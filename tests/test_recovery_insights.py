from unittest.mock import patch

from app.recovery_insights import build_recovery_insights


@patch("app.recovery_insights.load_monthly_review_history")
@patch("app.recovery_insights.load_weekly_review_history")
@patch("app.recovery_insights.get_recent_checkins")
@patch("app.recovery_insights.load_step_work")
@patch("app.recovery_insights.load_profile")
@patch("app.recovery_insights.calculate_sobriety_days")
def test_build_recovery_insights_with_full_data(
    mock_sobriety_days,
    mock_profile,
    mock_step_work,
    mock_checkins,
    mock_weekly_history,
    mock_monthly_history,
):
    mock_sobriety_days.return_value = 370

    mock_profile.return_value = {
        "sobriety_date": "2025-08-10",
    }

    mock_step_work.return_value = {
        "current_step": 1,
        "assignments": [
            {
                "step": 1,
                "completed": False,
            },
            {
                "step": 1,
                "completed": True,
            },
        ],
    }

    mock_checkins.return_value = [
        {},
        {},
        {},
        {},
    ]

    mock_weekly_history.return_value = [
        {
            "week_start": "2026-08-06",
            "week_end": "2026-08-12",
            "checkin_days": 3,
            "journal_entries": 3,
        }
    ]

    mock_monthly_history.return_value = [
        {
            "snapshot_date": "2026-08-15",
            "period_start": "2026-08-06",
            "period_end": "2026-08-12",
            "weekly_reviews_included": 1,
            "checkin_days": 3,
            "journal_entries": 3,
        }
    ]

    result = build_recovery_insights()

    assert "Sobriety Days: 370" in result
    assert "Current Step: 1" in result
    assert "Open Step Assignments: 1" in result
    assert "Check-In Days Available: 4/7" in result
    assert "2026-08-06 to 2026-08-12" in result
    assert "Snapshot Date: 2026-08-15" in result


@patch("app.recovery_insights.load_monthly_review_history")
@patch("app.recovery_insights.load_weekly_review_history")
@patch("app.recovery_insights.get_recent_checkins")
@patch("app.recovery_insights.load_step_work")
@patch("app.recovery_insights.load_profile")
@patch("app.recovery_insights.calculate_sobriety_days")
def test_build_recovery_insights_handles_missing_history(
    mock_sobriety_days,
    mock_profile,
    mock_step_work,
    mock_checkins,
    mock_weekly_history,
    mock_monthly_history,
):
    mock_sobriety_days.return_value = None
    mock_profile.return_value = {}
    mock_step_work.return_value = {
        "current_step": 1,
        "assignments": [],
    }
    mock_checkins.return_value = []
    mock_weekly_history.return_value = []
    mock_monthly_history.return_value = []

    result = build_recovery_insights()

    assert "Sobriety Days: Not configured" in result
    assert "Check-In Days Available: 0/7" in result
    assert "No saved weekly review available." in result
    assert "No saved monthly review available." in result