from unittest.mock import patch

from app.monthly_review import (
    build_monthly_review,
    get_recent_weekly_reviews,
)


def sample_history():
    return [
        {
            "week_start": "2026-07-16",
            "week_end": "2026-07-22",
            "checkin_days": 2,
            "journal_entries": 1,
            "action_totals": {
                "prayer_meditation": 2,
                "recovery_contact": 1,
                "meeting": 1,
                "step_work": 1,
                "journal": 1,
                "service": 0,
            },
        },
        {
            "week_start": "2026-07-23",
            "week_end": "2026-07-29",
            "checkin_days": 3,
            "journal_entries": 2,
            "action_totals": {
                "prayer_meditation": 3,
                "recovery_contact": 2,
                "meeting": 1,
                "step_work": 1,
                "journal": 2,
                "service": 1,
            },
        },
        {
            "week_start": "2026-07-30",
            "week_end": "2026-08-05",
            "checkin_days": 4,
            "journal_entries": 2,
            "action_totals": {
                "prayer_meditation": 4,
                "recovery_contact": 3,
                "meeting": 2,
                "step_work": 2,
                "journal": 2,
                "service": 1,
            },
        },
        {
            "week_start": "2026-08-06",
            "week_end": "2026-08-12",
            "checkin_days": 5,
            "journal_entries": 3,
            "action_totals": {
                "prayer_meditation": 5,
                "recovery_contact": 4,
                "meeting": 2,
                "step_work": 2,
                "journal": 3,
                "service": 2,
            },
        },
    ]


@patch("app.monthly_review.load_weekly_review_history")
def test_get_recent_weekly_reviews_returns_latest_four(mock_history):
    history = sample_history() + [
        {
            "week_start": "2026-07-09",
            "week_end": "2026-07-15",
        }
    ]

    mock_history.return_value = history

    reviews = get_recent_weekly_reviews(limit=4)

    assert len(reviews) == 4
    assert reviews[-1]["week_end"] == "2026-08-12"
    assert reviews[0]["week_end"] == "2026-07-22"


@patch("app.monthly_review.get_recent_weekly_reviews")
def test_build_monthly_review_aggregates_four_weeks(mock_reviews):
    mock_reviews.return_value = sample_history()

    result = build_monthly_review()

    assert "Weekly Reviews Included: 4/4" in result
    assert "Check-In Days: 14" in result
    assert "Journal Entries: 8" in result
    assert "Prayer / meditation: 14" in result
    assert "Recovery contact: 10" in result
    assert "Service: 4" in result


@patch("app.monthly_review.get_recent_weekly_reviews")
def test_build_monthly_review_handles_partial_month(mock_reviews):
    mock_reviews.return_value = sample_history()[-2:]

    result = build_monthly_review()

    assert "Weekly Reviews Included: 2/4" in result
    assert "Check-In Days: 9" in result
    assert "Journal Entries: 5" in result


@patch("app.monthly_review.get_recent_weekly_reviews")
def test_build_monthly_review_handles_no_history(mock_reviews):
    mock_reviews.return_value = []

    result = build_monthly_review()

    assert "No saved weekly reviews are available yet." in result