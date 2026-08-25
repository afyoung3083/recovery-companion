from pathlib import Path
from typing import Any

from app.paths import (
    BACKUP_DIR,
    CHECKIN_FILE,
    FELLOWSHIP_FILE,
    GOALS_FILE,
    JOURNAL_FILE,
    MONTHLY_REVIEW_HISTORY_FILE,
    PROFILE_FILE,
    ROUTINES_FILE,
    STEP_WORK_FILE,
    WEEKLY_REVIEW_HISTORY_FILE,
)


DELETE_CONFIRMATION = "DELETE MY RECOVERY DATA"

DATA_FILES = (
    PROFILE_FILE,
    JOURNAL_FILE,
    STEP_WORK_FILE,
    FELLOWSHIP_FILE,
    CHECKIN_FILE,
    WEEKLY_REVIEW_HISTORY_FILE,
    MONTHLY_REVIEW_HISTORY_FILE,
    GOALS_FILE,
    ROUTINES_FILE,
)

BACKUP_PATTERN = "recovery-companion-backup-*.json"


def delete_all_recovery_data(
    confirmation: str,
) -> dict[str, Any]:
    """
    Permanently remove Recovery Companion-owned local recovery data.

    The caller must supply the exact confirmation phrase.
    Recovery Companion-created backup files are also removed so
    deleted recovery data is not retained in the app's backup store.
    """

    if confirmation.strip() != DELETE_CONFIRMATION:
        raise ValueError(
            "Confirmation phrase does not match."
        )

    deleted_data_files = 0

    for path in DATA_FILES:
        try:
            path.unlink()
            deleted_data_files += 1
        except FileNotFoundError:
            pass

    deleted_backup_files = 0

    if BACKUP_DIR.exists():
        for backup_path in BACKUP_DIR.glob(
            BACKUP_PATTERN
        ):
            if not backup_path.is_file():
                continue

            backup_path.unlink()
            deleted_backup_files += 1

    return {
        "deleted": True,
        "deleted_data_files": deleted_data_files,
        "deleted_backup_files": deleted_backup_files,
    }
