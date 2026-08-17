from pathlib import Path


# ============================================================
# Recovery Companion filesystem layout
# ============================================================

# Resolve paths relative to the application project rather than
# the process's current working directory.
PROJECT_ROOT = Path(__file__).resolve().parent.parent

DATA_DIR = PROJECT_ROOT / "data"
BACKUP_DIR = PROJECT_ROOT / "backups"


# ============================================================
# Local data files
# ============================================================

PROFILE_FILE = DATA_DIR / "profile.json"
JOURNAL_FILE = DATA_DIR / "journal_entries.json"
STEP_WORK_FILE = DATA_DIR / "step_work.json"
FELLOWSHIP_FILE = DATA_DIR / "fellowship_contacts.json"
CHECKIN_FILE = DATA_DIR / "daily_checkins.json"

WEEKLY_REVIEW_HISTORY_FILE = DATA_DIR / "weekly_reviews.json"
MONTHLY_REVIEW_HISTORY_FILE = DATA_DIR / "monthly_reviews.json"

GOALS_FILE = DATA_DIR / "goals.json"
ROUTINES_FILE = DATA_DIR / "routines.json"


# ============================================================
# Directory helpers
# ============================================================

def ensure_data_directory() -> None:
    """Create the local Recovery Companion data directory."""

    DATA_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )


def ensure_backup_directory() -> None:
    """Create the local Recovery Companion backup directory."""

    BACKUP_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )