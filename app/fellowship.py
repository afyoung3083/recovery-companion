import json
from pathlib import Path
from typing import Any

# fellowship.py
from app.paths import (
    FELLOWSHIP_FILE,
    ensure_data_directory,
)


VALID_CONTACT_TYPES = {
    "sponsor",
    "sponsee",
    "dsr",
    "fellowship",
    "therapist",
    "clergy",
    "family",
    "other",
}


def load_contacts() -> list[dict[str, Any]]:
    ensure_data_directory()

    if not FELLOWSHIP_FILE.exists():
        return []

    with FELLOWSHIP_FILE.open("r", encoding="utf-8") as file:
        return json.load(file)


def save_contacts(contacts: list[dict[str, Any]]) -> None:
    ensure_data_directory()

    with FELLOWSHIP_FILE.open("w", encoding="utf-8") as file:
        json.dump(
            contacts,
            file,
            indent=2,
            ensure_ascii=False,
        )


def add_contact(
    handle: str,
    contact_type: str,
    contact_method: str = "",
    notes: str = "",
) -> dict[str, Any]:
    normalized_type = contact_type.strip().lower()

    if normalized_type not in VALID_CONTACT_TYPES:
        raise ValueError(
            "Contact type must be sponsor, sponsee, dsr, fellowship, "
            "therapist, clergy, family, or other."
        )

    contacts = load_contacts()

    contact = {
        "id": len(contacts) + 1,
        "handle": handle.strip(),
        "contact_type": normalized_type,
        "contact_method": contact_method.strip(),
        "notes": notes.strip(),
        "active": True,
    }

    contacts.append(contact)
    save_contacts(contacts)

    return contact



def update_contact(
    contact_id: int,
    handle: str,
    contact_type: str,
    contact_method: str = "",
    notes: str = "",
) -> dict[str, Any] | None:
    """Update an existing fellowship contact."""

    normalized_handle = handle.strip()
    normalized_type = contact_type.strip().lower()

    if not normalized_handle:
        raise ValueError(
            "Name or handle is required."
        )

    if normalized_type not in VALID_CONTACT_TYPES:
        raise ValueError(
            "Contact type must be sponsor, sponsee, dsr, fellowship, "
            "therapist, clergy, family, or other."
        )

    contacts = load_contacts()

    for contact in contacts:
        if contact.get("id") == contact_id:
            contact["handle"] = normalized_handle
            contact["contact_type"] = normalized_type
            contact["contact_method"] = (
                contact_method.strip()
            )
            contact["notes"] = notes.strip()

            save_contacts(contacts)
            return contact

    return None


def set_contact_active(
    contact_id: int,
    active: bool,
) -> dict[str, Any] | None:
    contacts = load_contacts()

    for contact in contacts:
        if contact.get("id") == contact_id:
            contact["active"] = active
            save_contacts(contacts)
            return contact

    return None


def format_contacts(
    contacts: list[dict[str, Any]],
) -> str:
    if not contacts:
        return "No fellowship contacts yet."

    lines: list[str] = []

    for contact in contacts:
        status = "active" if contact.get("active", True) else "inactive"

        lines.append(
            f"[{contact['id']}] {contact['handle']}\n"
            f"Type: {contact['contact_type']}\n"
            f"Contact: {contact.get('contact_method') or 'not provided'}\n"
            f"Status: {status}\n"
            f"Notes: {contact.get('notes') or 'none'}"
        )

    return "\n\n".join(lines)

def recommend_contacts(
    contacts: list[dict[str, Any]],
    limit: int = 3,
) -> list[dict[str, Any]]:
    priority = {
        "sponsor": 1,
        "dsr": 2,
        "fellowship": 3,
        "therapist": 4,
        "clergy": 5,
        "family": 6,
        "sponsee": 7,
        "other": 8,
    }

    active_contacts = [
        contact
        for contact in contacts
        if contact.get("active", True)
    ]

    ranked_contacts = sorted(
        active_contacts,
        key=lambda contact: (
            priority.get(contact.get("contact_type", "other"), 99),
            contact.get("id", 0),
        ),
    )

    return ranked_contacts[:limit]