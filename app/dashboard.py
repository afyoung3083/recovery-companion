from datetime import date, datetime
from typing import Any

from app.fellowship import load_contacts, recommend_contacts
from app.journal import load_entries
from app.step_work import load_step_work
from app.profile import load_profile


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