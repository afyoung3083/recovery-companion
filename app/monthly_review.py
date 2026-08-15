from typing import Any

from app.daily_checkin import CHECKIN_FIELDS
from app.weekly_review import load_weekly_review_history


def get_recent_weekly_reviews(
    limit: int = 4,
) -> list[dict[str, Any]]:
    """Return the most recent saved weekly review snapshots."""

    history = load_weekly_review_history()

    sorted_history = sorted(
        history,
        key=lambda item: item.get("week_end", ""),
    )

    return sorted_history[-limit:]


def build_monthly_review() -> str:
    """
    Build a deterministic review from up to four saved weekly reviews.

    This is a rolling four-week summary, not calendar-month accounting.
    """

    reviews = get_recent_weekly_reviews(limit=4)

    if not reviews:
        return (
            "Monthly Recovery Review\n"
            + "=" * 50
            + "\n\n"
            + "No saved weekly reviews are available yet."
        )

    total_checkin_days = sum(
        review.get("checkin_days", 0)
        for review in reviews
    )

    total_journal_entries = sum(
        review.get("journal_entries", 0)
        for review in reviews
    )

    action_totals = {
        field: 0
        for field in CHECKIN_FIELDS
    }

    for review in reviews:
        weekly_totals = review.get(
            "action_totals",
            {},
        )

        for field in CHECKIN_FIELDS:
            action_totals[field] += weekly_totals.get(
                field,
                0,
            )

    labels = {
        "prayer_meditation": "Prayer / meditation",
        "recovery_contact": "Recovery contact",
        "meeting": "Meeting",
        "step_work": "Step work",
        "journal": "Journal",
        "service": "Service",
    }

    first_week = reviews[0]
    last_week = reviews[-1]

    lines = [
        "Monthly Recovery Review",
        "=" * 50,
        "",
        (
            f"Period: {first_week.get('week_start', '?')} "
            f"to {last_week.get('week_end', '?')}"
        ),
        f"Weekly Reviews Included: {len(reviews)}/4",
        f"Check-In Days: {total_checkin_days}",
        f"Journal Entries: {total_journal_entries}",
        "",
        "Recovery Actions:",
    ]

    for field in CHECKIN_FIELDS:
        lines.append(
            f"  {labels[field]}: {action_totals[field]}"
        )

    return "\n".join(lines)