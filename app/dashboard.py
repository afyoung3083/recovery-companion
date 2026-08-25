from datetime import date, datetime
from typing import Any

from app.fellowship import load_contacts, recommend_contacts
from app.journal import load_entries
from app.step_work import load_step_work
from app.profile import load_profile
from app.daily_checkin import (
    CHECKIN_FIELDS,
    get_checkin_for_date,
)

def calculate_sobriety_days(sobriety_date: str | None) -> int | None:
    if not sobriety_date:
        return None

    start_date = date.fromisoformat(sobriety_date)
    return (date.today() - start_date).days


def get_latest_journal_entry(
    entries: list[dict[str, Any]],
) -> dict[str, Any] | None:
    if not entries:
        return None

    return max(
        entries,
        key=lambda entry: entry.get("created_at", ""),
    )


def get_open_assignments(
    step_work: dict[str, Any],
) -> list[dict[str, Any]]:
    current_step = step_work.get("current_step", 1)

    return [
        assignment
        for assignment in step_work.get("assignments", [])
        if (
            assignment.get("step") == current_step
            and not assignment.get("completed", False)
        )
    ]



def get_dashboard_data() -> dict[str, Any]:
    """Return structured deterministic Dashboard data."""

    step_work = load_step_work()
    journal_entries = load_entries()
    contacts = load_contacts()
    profile = load_profile()

    current_step = step_work.get("current_step", 1)
    open_assignments = get_open_assignments(step_work)
    latest_entry = get_latest_journal_entry(journal_entries)
    recommended_contacts = recommend_contacts(
        contacts=contacts,
        limit=3,
    )

    checkin = get_checkin_for_date(
        date.today().isoformat()
    )

    if checkin is None:
        checkin_data: dict[str, Any] = {
            "saved": False,
            "completed_count": 0,
            "total": len(CHECKIN_FIELDS),
            "note": "",
        }
    else:
        checkin_data = {
            "saved": True,
            "completed_count": sum(
                1
                for field in CHECKIN_FIELDS
                if checkin.get(field, False)
            ),
            "total": len(CHECKIN_FIELDS),
            "note": str(
                checkin.get("note", "")
            ).strip(),
        }

    if latest_entry is None:
        latest_entry_data = None
    else:
        latest_entry_data = {
            "id": latest_entry.get("id"),
            "created_at": latest_entry.get(
                "created_at",
                "",
            ),
            "text": latest_entry.get(
                "text",
                "",
            ),
        }

    assignment_data = [
        {
            "id": assignment.get("id"),
            "text": assignment.get(
                "text",
                "",
            ),
        }
        for assignment in open_assignments
    ]

    contact_data = [
        {
            "id": contact.get("id"),
            "handle": contact.get(
                "handle",
                "",
            ),
            "contact_type": contact.get(
                "contact_type",
                "",
            ),
            "contact_method": contact.get(
                "contact_method",
                "",
            ),
            "notes": contact.get(
                "notes",
                "",
            ),
            "active": contact.get(
                "active",
                True,
            ),
        }
        for contact in recommended_contacts
    ]

    sobriety_date = profile.get(
        "sobriety_date"
    )

    return {
        "sobriety_date": sobriety_date,
        "sobriety_days": calculate_sobriety_days(
            sobriety_date
        ),
        "today_checkin": checkin_data,
        "current_step": current_step,
        "open_assignments": assignment_data,
        "latest_journal_entry": latest_entry_data,
        "recommended_contacts": contact_data,
        "generated_at": datetime.now().isoformat(
            timespec="seconds"
        ),
    }

def build_dashboard() -> str:
    step_work = load_step_work()
    journal_entries = load_entries()
    contacts = load_contacts()
    profile = load_profile()

    current_step = step_work.get("current_step", 1)
    open_assignments = get_open_assignments(step_work)
    latest_entry = get_latest_journal_entry(journal_entries)
    recommended_contacts = recommend_contacts(
        contacts=contacts,
        limit=3,
    )

    lines: list[str] = []

    lines.append("Daily Recovery Dashboard")
    lines.append("=" * 50)

    sobriety_days = calculate_sobriety_days(
        profile.get("sobriety_date")
    )

    if sobriety_days is None:
        lines.append("Sobriety: not set")
    else:
        lines.append(
            f"Sobriety: {sobriety_days} day(s)"
        )

    lines.append(format_today_checkin())
    lines.append("")
    
    lines.append(f"Current Step: {current_step}")
    lines.append("")

    lines.append("Open Step Assignments:")

    if not open_assignments:
        lines.append("  None")
    else:
        for assignment in open_assignments:
            lines.append(
                f"  [{assignment['id']}] {assignment['text']}"
            )

    lines.append("")
    lines.append("Latest Journal Entry:")

    if latest_entry is None:
        lines.append("  None")
    else:
        lines.append(
            f"  {latest_entry.get('created_at', '')}"
        )
        lines.append(
            f"  {latest_entry.get('text', '')}"
        )

    lines.append("")
    lines.append("Top Fellowship Contacts:")

    if not recommended_contacts:
        lines.append("  None")
    else:
        for index, contact in enumerate(
            recommended_contacts,
            start=1,
        ):
            lines.append(
                f"  {index}. {contact['handle']} "
                f"({contact['contact_type']})"
            )

    lines.append("")
    lines.append(
        f"Generated: {datetime.now().isoformat(timespec='seconds')}"
    )

    return "\n".join(lines)

def format_today_checkin() -> str:
    checkin = get_checkin_for_date(
        date.today().isoformat()
    )

    if checkin is None:
        return "Today's Check-In: not completed"

    completed = sum(
        1
        for field in CHECKIN_FIELDS
        if checkin.get(field, False)
    )

    total = len(CHECKIN_FIELDS)

    lines = [
        f"Today's Check-In: {completed}/{total} completed"
    ]

    note = checkin.get("note", "").strip()

    if note:
        lines.append(f"Daily Note: {note}")

    return "\n".join(lines)