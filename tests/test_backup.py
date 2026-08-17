import json
from pathlib import Path
from unittest.mock import patch

from app.backup import (
    BACKUP_FORMAT_VERSION,
    build_backup_payload,
    load_backup_file,
    restore_backup,
    validate_backup_payload,
)


def sample_payload():
    """Return a complete valid backup payload."""

    return {
        "metadata": {
            "backup_format_version": BACKUP_FORMAT_VERSION,
            "created_at": "2026-08-16T18:20:00",
        },
        "profile": {
            "sobriety_date": "2025-08-10",
        },
        "journal_entries": [],
        "step_work": {
            "current_step": 1,
            "assignments": [],
            "notes": [],
        },
        "fellowship_contacts": [],
        "daily_checkins": [],
        "weekly_reviews": [],
        "monthly_reviews": [],
        "goals": [],
        "routines": [],
    }


@patch("app.backup.load_routines")
@patch("app.backup.load_goals")
@patch("app.backup.load_monthly_review_history")
@patch("app.backup.load_weekly_review_history")
@patch("app.backup.load_checkins")
@patch("app.backup.load_contacts")
@patch("app.backup.load_step_work")
@patch("app.backup.load_entries")
@patch("app.backup.load_profile")
def test_build_backup_payload_contains_all_sections(
    mock_profile,
    mock_entries,
    mock_step_work,
    mock_contacts,
    mock_checkins,
    mock_weekly,
    mock_monthly,
    mock_goals,
    mock_routines,
):
    mock_profile.return_value = {}
    mock_entries.return_value = []
    mock_step_work.return_value = {}
    mock_contacts.return_value = []
    mock_checkins.return_value = []
    mock_weekly.return_value = []
    mock_monthly.return_value = []
    mock_goals.return_value = []
    mock_routines.return_value = []

    payload = build_backup_payload()

    expected_sections = {
        "metadata",
        "profile",
        "journal_entries",
        "step_work",
        "fellowship_contacts",
        "daily_checkins",
        "weekly_reviews",
        "monthly_reviews",
        "goals",
        "routines",
    }

    assert set(payload.keys()) == expected_sections


def test_validate_backup_payload_accepts_valid_backup():
    validate_backup_payload(
        sample_payload()
    )


def test_validate_backup_payload_rejects_missing_section():
    payload = sample_payload()
    del payload["goals"]

    try:
        validate_backup_payload(payload)
    except ValueError as error:
        assert "missing required section" in str(error).lower()
    else:
        raise AssertionError(
            "Expected ValueError for missing backup section."
        )


def test_validate_backup_payload_rejects_wrong_version():
    payload = sample_payload()
    payload["metadata"]["backup_format_version"] = 999

    try:
        validate_backup_payload(payload)
    except ValueError as error:
        assert (
            str(error)
            == "Unsupported backup format version."
        )
    else:
        raise AssertionError(
            "Expected ValueError for unsupported backup version."
        )


def test_load_backup_file_reads_valid_json(
    tmp_path: Path,
):
    backup_path = tmp_path / "backup.json"

    with backup_path.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            sample_payload(),
            file,
        )

    payload = load_backup_file(
        backup_path
    )

    assert payload["profile"]["sobriety_date"] == "2025-08-10"


def test_restore_backup_writes_validated_data(
    tmp_path: Path,
):
    backup_path = tmp_path / "backup.json"

    with backup_path.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            sample_payload(),
            file,
        )

    profile_file = tmp_path / "profile.json"
    journal_file = tmp_path / "journal.json"
    step_file = tmp_path / "step.json"
    fellowship_file = tmp_path / "fellowship.json"
    checkin_file = tmp_path / "checkins.json"
    weekly_file = tmp_path / "weekly.json"
    monthly_file = tmp_path / "monthly.json"
    goals_file = tmp_path / "goals.json"
    routines_file = tmp_path / "routines.json"

    with (
        patch(
            "app.backup.PROFILE_FILE",
            profile_file,
        ),
        patch(
            "app.backup.JOURNAL_FILE",
            journal_file,
        ),
        patch(
            "app.backup.STEP_WORK_FILE",
            step_file,
        ),
        patch(
            "app.backup.FELLOWSHIP_FILE",
            fellowship_file,
        ),
        patch(
            "app.backup.CHECKIN_FILE",
            checkin_file,
        ),
        patch(
            "app.backup.WEEKLY_REVIEW_HISTORY_FILE",
            weekly_file,
        ),
        patch(
            "app.backup.MONTHLY_REVIEW_HISTORY_FILE",
            monthly_file,
        ),
        patch(
            "app.backup.GOALS_FILE",
            goals_file,
        ),
        patch(
            "app.backup.ROUTINES_FILE",
            routines_file,
        ),
    ):
        restore_backup(
            backup_path
        )

    with profile_file.open(
        "r",
        encoding="utf-8",
    ) as file:
        restored_profile = json.load(file)

    assert (
        restored_profile["sobriety_date"]
        == "2025-08-10"
    )

    assert journal_file.exists()
    assert step_file.exists()
    assert fellowship_file.exists()
    assert checkin_file.exists()
    assert weekly_file.exists()
    assert monthly_file.exists()
    assert goals_file.exists()
    assert routines_file.exists()