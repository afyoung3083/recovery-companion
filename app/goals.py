import json
from datetime import date
from pathlib import Path
from typing import Any


# ============================================================
# Configuration
# ============================================================

GOALS_FILE = Path("data/goals.json")

VALID_AREAS = {
    "connection",
    "step_work",
    "meetings",
    "prayer",
    "journal",
    "service",
    "health",
    "other",
}


# ============================================================
# Persistence
# ============================================================

def load_goals() -> list[dict[str, Any]]:
    """Load locally saved recovery goals."""

    if not GOALS_FILE.exists():
        return []

    try:
        with GOALS_FILE.open(
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


def save_goals(
    goals: list[dict[str, Any]],
) -> None:
    """Persist the full goal list locally."""

    GOALS_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with GOALS_FILE.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            goals,
            file,
            indent=2,
        )


# ============================================================
# Goal creation and updates
# ============================================================

def add_goal(
    text: str,
    area: str,
    target_date: str = "",
) -> dict[str, Any]:
    """Create and save a new active recovery goal."""

    text = text.strip()
    area = area.strip().lower()
    target_date = target_date.strip()

    if not text:
        raise ValueError(
            "Goal text cannot be empty."
        )

    if area not in VALID_AREAS:
        raise ValueError(
            "Invalid recovery area."
        )

    if target_date:
        try:
            parsed_target = date.fromisoformat(
                target_date
            )
        except ValueError as error:
            raise ValueError(
                "Target date must use YYYY-MM-DD format."
            ) from error

        if parsed_target < date.today():
            raise ValueError(
                "Target date cannot be in the past."
            )

    goals = load_goals()

    next_id = (
        max(
            (
                goal.get("id", 0)
                for goal in goals
            ),
            default=0,
        )
        + 1
    )

    goal = {
        "id": next_id,
        "text": text,
        "area": area,
        "target_date": target_date,
        "status": "active",
        "created_date": date.today().isoformat(),
        "completed_date": "",
    }

    goals.append(
        goal
    )

    save_goals(
        goals
    )

    return goal


def complete_goal(
    goal_id: int,
) -> dict[str, Any] | None:
    """Mark an active goal complete."""

    goals = load_goals()

    for goal in goals:
        if goal.get("id") != goal_id:
            continue

        goal["status"] = "completed"
        goal["completed_date"] = (
            date.today().isoformat()
        )

        save_goals(
            goals
        )

        return goal

    return None


def reactivate_goal(
    goal_id: int,
) -> dict[str, Any] | None:
    """Return a completed goal to active status."""

    goals = load_goals()

    for goal in goals:
        if goal.get("id") != goal_id:
            continue

        goal["status"] = "active"
        goal["completed_date"] = ""

        save_goals(
            goals
        )

        return goal

    return None


# ============================================================
# Queries and formatting
# ============================================================

def get_active_goals() -> list[dict[str, Any]]:
    """Return active goals only."""

    return [
        goal
        for goal in load_goals()
        if goal.get("status") == "active"
    ]


def format_goals(
    goals: list[dict[str, Any]],
) -> str:
    """Format goals for the CLI."""

    if not goals:
        return "No recovery goals saved."

    lines: list[str] = []

    for goal in goals:
        status = goal.get(
            "status",
            "active",
        )

        lines.append(
            f"[{goal.get('id', '?')}] "
            f"{goal.get('text', '')}"
        )

        lines.append(
            f"    Area: {goal.get('area', 'other')}"
        )

        target_date = goal.get(
            "target_date",
            "",
        )

        if target_date:
            lines.append(
                f"    Target: {target_date}"
            )

        lines.append(
            f"    Status: {status}"
        )

        lines.append("")

    return "\n".join(
        lines
    ).rstrip()