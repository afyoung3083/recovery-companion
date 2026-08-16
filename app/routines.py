import json
from datetime import date
from pathlib import Path
from typing import Any


# ============================================================
# Configuration
# ============================================================

ROUTINES_FILE = Path("data/routines.json")

VALID_FREQUENCIES = {
    "daily",
    "weekly",
}

VALID_AREAS = {
    "connection",
    "meetings",
    "step_work",
    "prayer",
    "journal",
    "service",
    "health",
    "other",
}


# ============================================================
# Persistence
# ============================================================

def load_routines() -> list[dict[str, Any]]:
    """Load locally saved recovery routines."""

    if not ROUTINES_FILE.exists():
        return []

    try:
        with ROUTINES_FILE.open(
            "r",
            encoding="utf-8",
        ) as file:
            data = json.load(file)

    except (
        json.JSONDecodeError,
        OSError,
    ):
        return []

    if not isinstance(data, list):
        return []

    return data


def save_routines(
    routines: list[dict[str, Any]],
) -> None:
    """Persist the complete routine list locally."""

    ROUTINES_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with ROUTINES_FILE.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            routines,
            file,
            indent=2,
        )


# ============================================================
# Routine creation and updates
# ============================================================

def add_routine(
    text: str,
    area: str,
    frequency: str,
    day_of_week: str = "",
) -> dict[str, Any]:
    """
    Create and save a new recovery routine.

    Weekly routines may optionally include a day name such as
    monday, tuesday, etc. Daily routines ignore day_of_week.
    """

    text = text.strip()
    area = area.strip().lower()
    frequency = frequency.strip().lower()
    day_of_week = day_of_week.strip().lower()

    if not text:
        raise ValueError(
            "Routine text cannot be empty."
        )

    if area not in VALID_AREAS:
        raise ValueError(
            "Invalid recovery area."
        )

    if frequency not in VALID_FREQUENCIES:
        raise ValueError(
            "Frequency must be daily or weekly."
        )

    valid_days = {
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
    }

    if frequency == "weekly":
        if day_of_week not in valid_days:
            raise ValueError(
                "Weekly routines require a valid day of week."
            )
    else:
        day_of_week = ""

    routines = load_routines()

    next_id = (
        max(
            (
                routine.get("id", 0)
                for routine in routines
            ),
            default=0,
        )
        + 1
    )

    routine = {
        "id": next_id,
        "text": text,
        "area": area,
        "frequency": frequency,
        "day_of_week": day_of_week,
        "active": True,
        "created_date": date.today().isoformat(),
    }

    routines.append(
        routine
    )

    save_routines(
        routines
    )

    return routine


def set_routine_active(
    routine_id: int,
    active: bool,
) -> dict[str, Any] | None:
    """Activate or deactivate a saved routine."""

    routines = load_routines()

    for routine in routines:
        if routine.get("id") != routine_id:
            continue

        routine["active"] = active

        save_routines(
            routines
        )

        return routine

    return None


# ============================================================
# Queries and formatting
# ============================================================

def get_active_routines() -> list[dict[str, Any]]:
    """Return active routines only."""

    return [
        routine
        for routine in load_routines()
        if routine.get("active", True)
    ]


def format_routines(
    routines: list[dict[str, Any]],
) -> str:
    """Format recovery routines for the CLI."""

    if not routines:
        return "No recovery routines saved."

    lines: list[str] = []

    for routine in routines:
        status = (
            "active"
            if routine.get("active", True)
            else "inactive"
        )

        lines.append(
            f"[{routine.get('id', '?')}] "
            f"{routine.get('text', '')}"
        )

        lines.append(
            f"    Area: {routine.get('area', 'other')}"
        )

        frequency = routine.get(
            "frequency",
            "daily",
        )

        if frequency == "weekly":
            day = routine.get(
                "day_of_week",
                "",
            )

            lines.append(
                f"    Schedule: Weekly - {day.title()}"
            )
        else:
            lines.append(
                "    Schedule: Daily"
            )

        lines.append(
            f"    Status: {status}"
        )

        lines.append("")

    return "\n".join(
        lines
    ).rstrip()