from datetime import date, timedelta
from typing import Any

from app.daily_checkin import CHECKIN_FIELDS, load_checkins
from app.journal import load_entries
from app.step_work import load_step_work


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