import json
from datetime import datetime
from pathlib import Path
from typing import Any

from app.daily_checkin import CHECKIN_FILE, load_checkins
from app.fellowship import FELLOWSHIP_FILE, load_contacts
from app.goals import GOALS_FILE, load_goals
from app.journal import JOURNAL_FILE, load_entries
from app.monthly_review import (
    MONTHLY_REVIEW_HISTORY_FILE,
    load_monthly_review_history,
)
from app.profile import PROFILE_FILE, load_profile
from app.routines import ROUTINES_FILE, load_routines
from app.step_work import STEP_WORK_FILE, load_step_work
from app.weekly_review import (
    WEEKLY_REVIEW_HISTORY_FILE,
    load_weekly_review_history,
)


# ============================================================
# Configuration
# ============================================================

BACKUP_DIRECTORY = Path("backups")

BACKUP_FORMAT_VERSION = 1


# ============================================================
# Backup creation
# ============================================================

def build_backup_payload() -> dict[str, Any]:
    """
    Collect all locally stored Recovery Companion data.

    The payload includes a small metadata section so future versions
    can validate and migrate backup files safely.
    """

    return {
        "metadata": {
            "backup_format_version": BACKUP_FORMAT_VERSION,
            "created_at": datetime.now().isoformat(
                timespec="seconds"
            ),
        },
        "profile": load_profile(),
        "journal_entries": load_entries(),
        "step_work": load_step_work(),
        "fellowship_contacts": load_contacts(),
        "daily_checkins": load_checkins(),
        "weekly_reviews": load_weekly_review_history(),
        "monthly_reviews": load_monthly_review_history(),
        "goals": load_goals(),
        "routines": load_routines(),
    }


def create_backup() -> Path:
    """
    Write a complete local backup to the backups directory.

    Returns the path of the newly created backup file.
    """

    BACKUP_DIRECTORY.mkdir(
        parents=True,
        exist_ok=True,
    )

    timestamp = datetime.now().strftime(
        "%Y%m%d-%H%M%S"
    )

    backup_path = BACKUP_DIRECTORY / (
        f"recovery-companion-backup-{timestamp}.json"
    )

    payload = build_backup_payload()

    with backup_path.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            payload,
            file,
            indent=2,
        )

    return backup_path


# ============================================================
# Backup loading and validation
# ============================================================

def load_backup_file(
    backup_path: Path,
) -> dict[str, Any]:
    """
    Load a backup file without modifying application data.

    Malformed JSON or unreadable files raise ValueError.
    """

    try:
        with backup_path.open(
            "r",
            encoding="utf-8",
        ) as file:
            payload = json.load(file)

    except (
        json.JSONDecodeError,
        OSError,
    ) as error:
        raise ValueError(
            "Backup file could not be read."
        ) from error

    if not isinstance(
        payload,
        dict,
    ):
        raise ValueError(
            "Backup file must contain a JSON object."
        )

    return payload


def validate_backup_payload(
    payload: dict[str, Any],
) -> None:
    """
    Validate the structure of a Recovery Companion backup.

    Validation happens before any restore operation so malformed
    backups cannot partially overwrite local data.
    """

    required_sections = {
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

    missing_sections = (
        required_sections
        - set(payload.keys())
    )

    if missing_sections:
        raise ValueError(
            "Backup is missing required section(s): "
            + ", ".join(
                sorted(missing_sections)
            )
        )

    metadata = payload.get(
        "metadata"
    )

    if not isinstance(
        metadata,
        dict,
    ):
        raise ValueError(
            "Backup metadata is invalid."
        )

    version = metadata.get(
        "backup_format_version"
    )

    if version != BACKUP_FORMAT_VERSION:
        raise ValueError(
            "Unsupported backup format version."
        )

    list_sections = {
        "journal_entries",
        "fellowship_contacts",
        "daily_checkins",
        "weekly_reviews",
        "monthly_reviews",
        "goals",
        "routines",
    }

    for section in list_sections:
        if not isinstance(
            payload.get(section),
            list,
        ):
            raise ValueError(
                f"Backup section '{section}' "
                "must contain a list."
            )

    if not isinstance(
        payload.get("profile"),
        dict,
    ):
        raise ValueError(
            "Backup profile section is invalid."
        )

    if not isinstance(
        payload.get("step_work"),
        dict,
    ):
        raise ValueError(
            "Backup Step Work section is invalid."
        )

# ============================================================
# Backup restore
# ============================================================

def restore_backup(
    backup_path: Path,
) -> None:
    """
    Restore all local Recovery Companion data from a backup file.

    The entire backup is loaded and validated before any local
    application data is changed.
    """

    payload = load_backup_file(
        backup_path
    )

    validate_backup_payload(
        payload
    )

    # Map each validated backup section to the application's
    # actual local persistence file.
    restore_targets = {
        PROFILE_FILE: payload["profile"],
        JOURNAL_FILE: payload["journal_entries"],
        STEP_WORK_FILE: payload["step_work"],
        FELLOWSHIP_FILE: payload["fellowship_contacts"],
        CHECKIN_FILE: payload["daily_checkins"],
        WEEKLY_REVIEW_HISTORY_FILE: payload["weekly_reviews"],
        MONTHLY_REVIEW_HISTORY_FILE: payload["monthly_reviews"],
        GOALS_FILE: payload["goals"],
        ROUTINES_FILE: payload["routines"],
    }

    for path, data in restore_targets.items():
        path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        with path.open(
            "w",
            encoding="utf-8",
        ) as file:
            json.dump(
                data,
                file,
                indent=2,
                ensure_ascii=False,
            )