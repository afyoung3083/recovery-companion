import json
from datetime import datetime
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
JOURNAL_FILE = DATA_DIR / "journal_entries.json"


def ensure_data_directory() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def load_entries() -> list[dict[str, Any]]:
    ensure_data_directory()

    if not JOURNAL_FILE.exists():
        return []

    with JOURNAL_FILE.open("r", encoding="utf-8") as file:
        return json.load(file)


def save_entries(entries: list[dict[str, Any]]) -> None:
    ensure_data_directory()

    with JOURNAL_FILE.open("w", encoding="utf-8") as file:
        json.dump(entries, file, indent=2, ensure_ascii=False)


def add_entry(text: str) -> dict[str, Any]:
    entries = load_entries()

    entry = {
        "id": len(entries) + 1,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "text": text,
    }

    entries.append(entry)
    save_entries(entries)

    return entry

def format_entries(entries: list[dict[str, Any]]) -> str:
    if not entries:
        return "No journal entries yet."

    formatted: list[str] = []

    for entry in reversed(entries):
        formatted.append(
            f"[{entry['id']}] {entry['created_at']}\n"
            f"{entry['text']}"
        )

    return "\n\n".join(formatted)