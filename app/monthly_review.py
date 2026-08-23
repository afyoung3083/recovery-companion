import json
from datetime import date
from pathlib import Path
from typing import Any
from app.paths import MONTHLY_REVIEW_HISTORY_FILE

from app.daily_checkin import CHECKIN_FIELDS
from app.weekly_review import load_weekly_review_history


# ============================================================
# Configuration
# ============================================================

# Local persistence file for saved rolling four-week snapshots.
MONTHLY_REVIEW_HISTORY_FILE = Path(
    "data/monthly_reviews.json"
)


# ============================================================
# Weekly-review source data
# ============================================================

def get_recent_weekly_reviews(
    limit: int = 4,
) -> list[dict[str, Any]]:
    """
    Return the most recent saved weekly review snapshots.

    Monthly reviews are built from saved weekly snapshots rather
    than directly from raw daily data.
    """

    history = load_weekly_review_history()

    sorted_history = sorted(
        history,
        key=lambda item: item.get(
            "week_end",
            "",
        ),
    )

    return sorted_history[-limit:]


# ============================================================
# Monthly review builder
# ============================================================

def build_monthly_review() -> str:
    """
    Build a deterministic rolling four-week Recovery Review.

    This is intentionally a rolling four-week summary rather than
    strict calendar-month accounting.
    """

    reviews = get_recent_weekly_reviews(
        limit=4
    )

    if not reviews:
        return (
            "Monthly Recovery Review\n"
            + "=" * 50
            + "\n\n"
            + "No saved weekly reviews are available yet."
        )

    total_checkin_days = sum(
        review.get(
            "checkin_days",
            0,
        )
        for review in reviews
    )

    total_journal_entries = sum(
        review.get(
            "journal_entries",
            0,
        )
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
            f"Period: "
            f"{first_week.get('week_start', '?')} "
            f"to {last_week.get('week_end', '?')}"
        ),
        (
            "Weekly Reviews Included: "
            f"{len(reviews)}/4"
        ),
        (
            f"Check-In Days: "
            f"{total_checkin_days}"
        ),
        (
            f"Journal Entries: "
            f"{total_journal_entries}"
        ),
        "",
        "Recovery Actions:",
    ]

    for field in CHECKIN_FIELDS:
        lines.append(
            f"  {labels[field]}: "
            f"{action_totals[field]}"
        )

    return "\n".join(lines)


# ============================================================
# Monthly-review persistence
# ============================================================

def load_monthly_review_history() -> list[dict[str, Any]]:
    """
    Load saved monthly-review snapshots from local storage.

    Missing, unreadable, or malformed data returns an empty list
    rather than crashing the application.
    """

    if not MONTHLY_REVIEW_HISTORY_FILE.exists():
        return []

    try:
        with MONTHLY_REVIEW_HISTORY_FILE.open(
            "r",
            encoding="utf-8",
        ) as file:
            data = json.load(file)

    except (
        json.JSONDecodeError,
        OSError,
    ):
        return []

    if not isinstance(
        data,
        list,
    ):
        return []

    return data


def save_monthly_review_snapshot() -> dict[str, Any]:
    """
    Save the current rolling four-week Monthly Recovery Review.

    Saving again on the same date replaces that day's snapshot
    instead of creating duplicates.
    """

    reviews = get_recent_weekly_reviews(
        limit=4
    )

    if not reviews:
        raise ValueError(
            "No saved weekly reviews are available "
            "for a monthly snapshot."
        )

    today = date.today()

    total_checkin_days = sum(
        review.get(
            "checkin_days",
            0,
        )
        for review in reviews
    )

    total_journal_entries = sum(
        review.get(
            "journal_entries",
            0,
        )
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

    snapshot = {
        "snapshot_date": today.isoformat(),
        "period_start": reviews[0].get(
            "week_start",
            "?",
        ),
        "period_end": reviews[-1].get(
            "week_end",
            "?",
        ),
        "weekly_reviews_included": len(
            reviews
        ),
        "checkin_days": total_checkin_days,
        "journal_entries": total_journal_entries,
        "action_totals": action_totals,
        "review": build_monthly_review(),
    }

    history = load_monthly_review_history()

    # Replace a snapshot already saved today instead of creating
    # duplicate records for the same snapshot date.
    history = [
        item
        for item in history
        if item.get(
            "snapshot_date"
        )
        != snapshot[
            "snapshot_date"
        ]
    ]

    history.append(
        snapshot
    )

    history.sort(
        key=lambda item: item.get(
            "snapshot_date",
            "",
        )
    )

    MONTHLY_REVIEW_HISTORY_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with MONTHLY_REVIEW_HISTORY_FILE.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            history,
            file,
            indent=2,
        )

    return snapshot


# ============================================================
# Monthly-review history formatting
# ============================================================

def format_monthly_review_history(
    history: list[dict[str, Any]],
    limit: int = 6,
) -> str:
    """
    Format recently saved Monthly Recovery Review snapshots.

    Most recent snapshots are shown first.
    """

    if not history:
        return (
            "No monthly review history yet."
        )

    recent = history[
        -limit:
    ][::-1]

    lines = [
        "Monthly Review History",
        "=" * 50,
    ]

    for item in recent:
        lines.append("")
        lines.append(
            "Snapshot: "
            f"{item.get('snapshot_date', '?')}"
        )
        lines.append(
            "Period: "
            f"{item.get('period_start', '?')} "
            f"to {item.get('period_end', '?')}"
        )
        lines.append(
            "Weekly Reviews Included: "
            f"{item.get('weekly_reviews_included', 0)}/4"
        )
        lines.append(
            "Check-In Days: "
            f"{item.get('checkin_days', 0)}"
        )
        lines.append(
            "Journal Entries: "
            f"{item.get('journal_entries', 0)}"
        )

    return "\n".join(
        lines
    )


# ============================================================
# Monthly-review comparison
# ============================================================

def compare_latest_monthly_reviews(
    history: list[dict[str, Any]],
) -> str:
    """
    Compare the two most recent saved monthly snapshots.

    Numerical changes are reported neutrally. This function does
    not label increases as improvement or decreases as regression.
    """

    if len(history) < 2:
        return (
            "At least two saved monthly reviews "
            "are needed for comparison."
        )

    sorted_history = sorted(
        history,
        key=lambda item: item.get(
            "snapshot_date",
            "",
        ),
    )

    previous = sorted_history[-2]
    current = sorted_history[-1]

    labels = {
        "prayer_meditation": "Prayer / meditation",
        "recovery_contact": "Recovery contact",
        "meeting": "Meeting",
        "step_work": "Step work",
        "journal": "Journal",
        "service": "Service",
    }

    lines = [
        "Monthly Review Comparison",
        "=" * 50,
        "",
        (
            "Previous snapshot: "
            f"{previous.get('snapshot_date', '?')}"
        ),
        (
            "Current snapshot:  "
            f"{current.get('snapshot_date', '?')}"
        ),
        "",
        (
            "Check-In Days: "
            f"{previous.get('checkin_days', 0)} "
            f"-> {current.get('checkin_days', 0)}"
        ),
        (
            "Journal Entries: "
            f"{previous.get('journal_entries', 0)} "
            f"-> {current.get('journal_entries', 0)}"
        ),
        "",
        "Recovery Actions:",
    ]

    previous_totals = previous.get(
        "action_totals",
        {},
    )

    current_totals = current.get(
        "action_totals",
        {},
    )

    for field in CHECKIN_FIELDS:
        previous_value = previous_totals.get(
            field,
            0,
        )

        current_value = current_totals.get(
            field,
            0,
        )

        difference = (
            current_value
            - previous_value
        )

        if difference > 0:
            change = f"+{difference}"
        else:
            change = str(difference)

        lines.append(
            f"  {labels[field]}: "
            f"{previous_value} "
            f"-> {current_value} "
            f"({change})"
        )

    return "\n".join(
        lines
    )