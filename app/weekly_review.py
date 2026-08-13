from datetime import date, timedelta
from typing import Any
import json
from pathlib import Path

from app.daily_checkin import CHECKIN_FIELDS, load_checkins
from app.journal import load_entries
from app.step_work import load_step_work

WEEKLY_REVIEW_HISTORY_FILE = Path("data/weekly_reviews.json")

def get_recent_checkins_for_week() -> list[dict[str, Any]]:
    today = date.today()
    start_date = today - timedelta(days=6)

    return [
        checkin
        for checkin in load_checkins()
        if start_date.isoformat()
        <= checkin.get("date", "")
        <= today.isoformat()
    ]


def get_recent_journal_entries_for_week() -> list[dict[str, Any]]:
    today = date.today()
    start_date = today - timedelta(days=6)

    entries = []

    for entry in load_entries():
        created_at = entry.get("created_at", "")
        entry_date = created_at[:10]

        if start_date.isoformat() <= entry_date <= today.isoformat():
            entries.append(entry)

    return entries


def build_weekly_review() -> str:
    checkins = get_recent_checkins_for_week()
    journal_entries = get_recent_journal_entries_for_week()
    step_work = load_step_work()

    current_step = step_work.get("current_step", 1)

    open_assignments = [
        assignment
        for assignment in step_work.get("assignments", [])
        if (
            assignment.get("step") == current_step
            and not assignment.get("completed", False)
        )
    ]

    action_totals = {
        field: 0
        for field in CHECKIN_FIELDS
    }

    for checkin in checkins:
        for field in CHECKIN_FIELDS:
            if checkin.get(field, False):
                action_totals[field] += 1

    labels = {
        "prayer_meditation": "Prayer / meditation",
        "recovery_contact": "Recovery contact",
        "meeting": "Meeting",
        "step_work": "Step work",
        "journal": "Journal",
        "service": "Service",
    }

    lines = [
        "Weekly Recovery Review",
        "=" * 50,
        "",
        f"Check-In Days: {len(checkins)}/7",
        "",
        "Recovery Actions:",
    ]

    for field in CHECKIN_FIELDS:
        lines.append(
            f"  {labels[field]}: {action_totals[field]}/{len(checkins) or 0}"
        )

    lines.append("")
    lines.append(
        f"Journal Entries This Week: {len(journal_entries)}"
    )

    lines.append("")
    lines.append(f"Current Step: {current_step}")
    lines.append("Open Step Assignments:")

    if not open_assignments:
        lines.append("  None")
    else:
        for assignment in open_assignments:
            lines.append(
                f"  [{assignment['id']}] {assignment['text']}"
            )

    recent_notes = [
        checkin.get("note", "").strip()
        for checkin in checkins
        if checkin.get("note", "").strip()
    ]

    lines.append("")
    lines.append("Recent Check-In Notes:")

    if not recent_notes:
        lines.append("  None")
    else:
        for note in recent_notes:
            lines.append(f"  - {note}")

    return "\n".join(lines)

def load_weekly_review_history() -> list[dict[str, Any]]:
    if not WEEKLY_REVIEW_HISTORY_FILE.exists():
        return []

    try:
        with WEEKLY_REVIEW_HISTORY_FILE.open(
            "r",
            encoding="utf-8",
        ) as file:
            data = json.load(file)
    except (json.JSONDecodeError, OSError):
        return []

    if not isinstance(data, list):
        return []

    return data


def save_weekly_review_snapshot() -> dict[str, Any]:
    today = date.today()
    week_start = today - timedelta(days=6)

    checkins = get_recent_checkins_for_week()

    action_totals = {
        field: sum(
            1
            for checkin in checkins
            if checkin.get(field, False)
        )
        for field in CHECKIN_FIELDS
    }

    snapshot = {
        "week_start": week_start.isoformat(),
        "week_end": today.isoformat(),
        "checkin_days": len(checkins),
        "action_totals": action_totals,
        "journal_entries": len(
            get_recent_journal_entries_for_week()
        ),
        "review": build_weekly_review(),
    }

    history = load_weekly_review_history()

    # Replace today's snapshot rather than creating duplicates
    # if the user saves the same weekly period more than once.
    history = [
        item
        for item in history
        if item.get("week_end") != snapshot["week_end"]
    ]

    history.append(snapshot)
    history.sort(
        key=lambda item: item.get("week_end", "")
    )

    WEEKLY_REVIEW_HISTORY_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with WEEKLY_REVIEW_HISTORY_FILE.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(history, file, indent=2)

    return snapshot

def format_weekly_review_history(
    history: list[dict[str, Any]],
    limit: int = 5,
) -> str:
    if not history:
        return "No weekly review history yet."

    recent = history[-limit:][::-1]

    lines = [
        "Weekly Review History",
        "=" * 50,
    ]

    for item in recent:
        lines.append("")
        lines.append(
            f"{item.get('week_start', '?')} "
            f"to {item.get('week_end', '?')}"
        )
        lines.append(
            f"Check-In Days: {item.get('checkin_days', 0)}/7"
        )
        lines.append(
            f"Journal Entries: {item.get('journal_entries', 0)}"
        )

    return "\n".join(lines)


def compare_latest_weekly_reviews(
    history: list[dict[str, Any]],
) -> str:
    if len(history) < 2:
        return "At least two saved weekly reviews are needed for comparison."

    previous = history[-2]
    current = history[-1]

    labels = {
        "prayer_meditation": "Prayer / meditation",
        "recovery_contact": "Recovery contact",
        "meeting": "Meeting",
        "step_work": "Step work",
        "journal": "Journal",
        "service": "Service",
    }

    lines = [
        "Weekly Review Comparison",
        "=" * 50,
        "",
        (
            f"Previous: {previous.get('week_start', '?')} "
            f"to {previous.get('week_end', '?')}"
        ),
        (
            f"Current:  {current.get('week_start', '?')} "
            f"to {current.get('week_end', '?')}"
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

    previous_totals = previous.get("action_totals", {})
    current_totals = current.get("action_totals", {})

    for field in CHECKIN_FIELDS:
        previous_value = previous_totals.get(field, 0)
        current_value = current_totals.get(field, 0)
        difference = current_value - previous_value

        if difference > 0:
            change = f"+{difference}"
        else:
            change = str(difference)

        lines.append(
            f"  {labels[field]}: "
            f"{previous_value} -> {current_value} "
            f"({change})"
        )

    return "\n".join(lines)