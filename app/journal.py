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


def add_entry(
    text: str,
    tags: list[str] | None = None,
) -> dict[str, Any]:
    entries = load_entries()

    entry = {
        "id": len(entries) + 1,
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "text": text,
        "tags": tags or [],
    }

    entries.append(entry)
    save_entries(entries)

    return entry

def format_entries(entries: list[dict[str, Any]]) -> str:
    if not entries:
        return "No journal entries yet."

    formatted: list[str] = []

    for entry in reversed(entries):
        tags = entry.get("tags", [])
        tag_text = ", ".join(tags) if tags else "none"

        formatted.append(
            f"[{entry['id']}] {entry['created_at']}\n"
            f"Tags: {tag_text}\n"
            f"{entry['text']}"
        )

    return "\n\n".join(formatted)

def search_entries(
    entries: list[dict[str, Any]],
    query: str,
) -> list[dict[str, Any]]:
    query_lower = query.strip().lower()

    if not query_lower:
        return entries

    matches: list[dict[str, Any]] = []

    for entry in entries:
        text = entry.get("text", "").lower()
        tags = [tag.lower() for tag in entry.get("tags", [])]

        if query_lower in text or any(
            query_lower in tag for tag in tags
        ):
            matches.append(entry)

    return matches

def filter_entries_by_tag(
    entries: list[dict[str, Any]],
    tag: str,
) -> list[dict[str, Any]]:
    tag_lower = tag.strip().lower()

    if not tag_lower:
        return entries

    return [
        entry
        for entry in entries
        if tag_lower in [
            existing_tag.lower()
            for existing_tag in entry.get("tags", [])
        ]
    ]