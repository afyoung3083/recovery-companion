import json
from datetime import date
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
CHECKIN_FILE = DATA_DIR / "daily_checkins.json"


CHECKIN_FIELDS = [
    "prayer_meditation",
    "recovery_contact",
    "meeting",
    "step_work",
    "journal",
    "service",
]


def ensure_data_directory() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def load_checkins() -> list[dict[str, Any]]:
    ensure_data_directory()

    if not CHECKIN_FILE.exists():
        return []

    with CHECKIN_FILE.open("r", encoding="utf-8") as file:
        return json.load(file)


def save_checkins(checkins: list[dict[str, Any]]) -> None:
    ensure_data_directory()

    with CHECKIN_FILE.open("w", encoding="utf-8") as file:
        json.dump(
            checkins,
            file,
            indent=2,
            ensure_ascii=False,
        )


def get_checkin_for_date(
    checkin_date: str,
) -> dict[str, Any] | None:
    for checkin in load_checkins():
        if checkin.get("date") == checkin_date:
            return checkin

    return None


def save_daily_checkin(
    values: dict[str, bool],
    note: str = "",
    checkin_date: str | None = None,
) -> dict[str, Any]:
    target_date = checkin_date or date.today().isoformat()
    checkins = load_checkins()

    existing = next(
        (
            checkin
            for checkin in checkins
            if checkin.get("date") == target_date
        ),
        None,
    )

    if existing is None:
        existing = {
            "date": target_date,
        }
        checkins.append(existing)

    for field in CHECKIN_FIELDS:
        existing[field] = bool(values.get(field, False))

    existing["note"] = note.strip()

    save_checkins(checkins)

    return existing


def format_checkin(checkin: dict[str, Any] | None) -> str:
    if checkin is None:
        return "No check-in saved for today."

    labels = {
        "prayer_meditation": "Prayer / meditation",
        "recovery_contact": "Recovery contact",
        "meeting": "Meeting",
        "step_work": "Step work",
        "journal": "Journal",
        "service": "Service",
    }

    lines = [
        f"Daily Check-In — {checkin['date']}",
        "=" * 50,
    ]

    for field in CHECKIN_FIELDS:
        mark = "✓" if checkin.get(field, False) else " "
        lines.append(
            f"[{mark}] {labels[field]}"
        )

    lines.append("")
    lines.append(
        f"Note: {checkin.get('note') or 'none'}"
    )

    return "\n".join(lines)