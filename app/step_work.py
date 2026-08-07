import json
from datetime import datetime
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
STEP_WORK_FILE = DATA_DIR / "step_work.json"


def ensure_data_directory() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def default_step_work() -> dict[str, Any]:
    return {
        "current_step": 1,
        "assignments": [],
        "notes": [],
    }


def load_step_work() -> dict[str, Any]:
    ensure_data_directory()

    if not STEP_WORK_FILE.exists():
        return default_step_work()

    with STEP_WORK_FILE.open("r", encoding="utf-8") as file:
        return json.load(file)


def save_step_work(step_work: dict[str, Any]) -> None:
    ensure_data_directory()

    with STEP_WORK_FILE.open("w", encoding="utf-8") as file:
        json.dump(
            step_work,
            file,
            indent=2,
            ensure_ascii=False,
        )


def set_current_step(step_number: int) -> dict[str, Any]:
    if step_number < 1 or step_number > 12:
        raise ValueError("Step number must be between 1 and 12.")

    step_work = load_step_work()
    step_work["current_step"] = step_number
    save_step_work(step_work)

    return step_work


def add_assignment(text: str) -> dict[str, Any]:
    step_work = load_step_work()

    assignments = step_work.setdefault("assignments", [])

    assignment = {
        "id": len(assignments) + 1,
        "step": step_work.get("current_step", 1),
        "text": text,
        "completed": False,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "completed_at": None,
    }

    assignments.append(assignment)
    save_step_work(step_work)

    return assignment


def complete_assignment(assignment_id: int) -> dict[str, Any] | None:
    step_work = load_step_work()

    for assignment in step_work.get("assignments", []):
        if assignment.get("id") == assignment_id:
            assignment["completed"] = True
            assignment["completed_at"] = datetime.now().isoformat(
                timespec="seconds"
            )
            save_step_work(step_work)
            return assignment

    return None


def add_step_note(text: str) -> dict[str, Any]:
    step_work = load_step_work()

    notes = step_work.setdefault("notes", [])

    note = {
        "id": len(notes) + 1,
        "step": step_work.get("current_step", 1),
        "text": text,
        "created_at": datetime.now().isoformat(timespec="seconds"),
    }

    notes.append(note)
    save_step_work(step_work)

    return note

def format_step_work(step_work: dict[str, Any]) -> str:
    current_step = step_work.get("current_step", 1)
    assignments = step_work.get("assignments", [])
    notes = step_work.get("notes", [])

    lines: list[str] = [
        f"Current Step: {current_step}",
        "",
        "Assignments:",
    ]

    current_assignments = [
        assignment
        for assignment in assignments
        if assignment.get("step") == current_step
    ]

    if not current_assignments:
        lines.append("  No assignments yet.")
    else:
        for assignment in current_assignments:
            status = "✓" if assignment.get("completed") else " "
            lines.append(
                f"  [{status}] {assignment['id']}: {assignment['text']}"
            )

    lines.append("")
    lines.append("Notes:")

    current_notes = [
        note
        for note in notes
        if note.get("step") == current_step
    ]

    if not current_notes:
        lines.append("  No notes yet.")
    else:
        for note in current_notes:
            lines.append(
                f"  [{note['id']}] {note['text']}"
            )

    return "\n".join(lines)