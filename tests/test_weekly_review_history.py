from app.weekly_review import (
    compare_latest_weekly_reviews,
    format_weekly_review_history,
)


def sample_history():
    return [
        {
            "week_start": "2026-07-30",
            "week_end": "2026-08-05",
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
            "week_start": "2026-08-06",
            "week_end": "2026-08-12",
            "checkin_days": 3,
            "journal_entries": 3,
            "action_totals": {
                "prayer_meditation": 3,
                "recovery_contact": 3,
                "meeting": 2,
                "step_work": 1,
                "journal": 2,
                "service": 1,
            },
        },
    ]


def test_format_weekly_review_history():
    output = format_weekly_review_history(
        sample_history()
    )

    assert "2026-08-06 to 2026-08-12" in output
    assert "Check-In Days: 3/7" in output
    assert "Journal Entries: 3" in output


def test_compare_latest_weekly_reviews():
    output = compare_latest_weekly_reviews(
        sample_history()
    )

    assert "Check-In Days: 2 -> 3" in output
    assert "Journal Entries: 1 -> 3" in output
    assert "Prayer / meditation: 2 -> 3 (+1)" in output
    assert "Service: 0 -> 1 (+1)" in output


def test_compare_requires_two_reviews():
    output = compare_latest_weekly_reviews(
        sample_history()[:1]
    )

    assert (
        "At least two saved weekly reviews "
        "are needed for comparison."
        in output
    )


def test_empty_weekly_review_history():
    output = format_weekly_review_history([])

    assert output == "No weekly review history yet."