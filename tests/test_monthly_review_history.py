from app.monthly_review import (
    compare_latest_monthly_reviews,
    format_monthly_review_history,
)


def sample_monthly_history():
    return [
        {
            "snapshot_date": "2026-07-15",
            "period_start": "2026-06-18",
            "period_end": "2026-07-15",
            "weekly_reviews_included": 4,
            "checkin_days": 12,
            "journal_entries": 8,
            "action_totals": {
                "prayer_meditation": 10,
                "recovery_contact": 9,
                "meeting": 5,
                "step_work": 4,
                "journal": 7,
                "service": 3,
            },
        },
        {
            "snapshot_date": "2026-08-15",
            "period_start": "2026-07-19",
            "period_end": "2026-08-15",
            "weekly_reviews_included": 4,
            "checkin_days": 15,
            "journal_entries": 11,
            "action_totals": {
                "prayer_meditation": 13,
                "recovery_contact": 12,
                "meeting": 6,
                "step_work": 5,
                "journal": 9,
                "service": 5,
            },
        },
    ]


def test_format_monthly_review_history():
    output = format_monthly_review_history(
        sample_monthly_history()
    )

    assert "Snapshot: 2026-08-15" in output
    assert "Weekly Reviews Included: 4/4" in output
    assert "Check-In Days: 15" in output
    assert "Journal Entries: 11" in output


def test_compare_latest_monthly_reviews():
    output = compare_latest_monthly_reviews(
        sample_monthly_history()
    )

    assert "Check-In Days: 12 -> 15" in output
    assert "Journal Entries: 8 -> 11" in output
    assert "Prayer / meditation: 10 -> 13 (+3)" in output
    assert "Service: 3 -> 5 (+2)" in output


def test_compare_monthly_reviews_requires_two_snapshots():
    output = compare_latest_monthly_reviews(
        sample_monthly_history()[:1]
    )

    assert (
        "At least two saved monthly reviews "
        "are needed for comparison."
        in output
    )


def test_empty_monthly_review_history():
    output = format_monthly_review_history([])

    assert output == "No monthly review history yet."