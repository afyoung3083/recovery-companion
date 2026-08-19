from unittest.mock import patch

from app.sync import (
    SYNC_SCHEMA_VERSION,
    build_sync_payload,
    validate_sync_payload,
)


@patch("app.sync.build_backup_payload")
def test_build_sync_payload(
    mock_build_backup_payload,
):
    mock_build_backup_payload.return_value = {
        "profile": {},
        "goals": [],
    }

    result = build_sync_payload()

    assert result == {
        "sync_schema_version": SYNC_SCHEMA_VERSION,
        "data": {
            "profile": {},
            "goals": [],
        },
    }


def test_validate_sync_payload_accepts_valid_payload():
    payload = {
        "sync_schema_version": SYNC_SCHEMA_VERSION,
        "data": {},
    }

    assert validate_sync_payload(payload) is True


def test_validate_sync_payload_rejects_wrong_version():
    payload = {
        "sync_schema_version": 999,
        "data": {},
    }

    assert validate_sync_payload(payload) is False


def test_validate_sync_payload_rejects_missing_data():
    payload = {
        "sync_schema_version": SYNC_SCHEMA_VERSION,
    }

    assert validate_sync_payload(payload) is False