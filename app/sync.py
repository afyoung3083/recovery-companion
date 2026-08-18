from typing import Any

from app.backup import build_backup_payload


SYNC_SCHEMA_VERSION = 1


def build_sync_payload() -> dict[str, Any]:
    """
    Build the local Recovery Companion state for synchronization.

    Sprint 31 defines the sync contract only. No data is transmitted
    to or stored by a cloud service yet.
    """

    return {
        "sync_schema_version": SYNC_SCHEMA_VERSION,
        "data": build_backup_payload(),
    }


def validate_sync_payload(
    payload: dict[str, Any],
) -> bool:
    """Validate the basic structure of a synchronization payload."""

    if payload.get("sync_schema_version") != SYNC_SCHEMA_VERSION:
        return False

    data = payload.get("data")

    if not isinstance(data, dict):
        return False

    return True