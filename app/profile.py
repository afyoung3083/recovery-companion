import json
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
PROFILE_FILE = DATA_DIR / "profile.json"


def ensure_data_directory() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def default_profile() -> dict[str, Any]:
    return {
        "sobriety_date": None,
    }


def load_profile() -> dict[str, Any]:
    ensure_data_directory()

    if not PROFILE_FILE.exists():
        return default_profile()

    with PROFILE_FILE.open("r", encoding="utf-8") as file:
        return json.load(file)


def save_profile(profile: dict[str, Any]) -> None:
    ensure_data_directory()

    with PROFILE_FILE.open("w", encoding="utf-8") as file:
        json.dump(
            profile,
            file,
            indent=2,
            ensure_ascii=False,
        )


def set_sobriety_date(sobriety_date: str) -> dict[str, Any]:
    profile = load_profile()
    profile["sobriety_date"] = sobriety_date
    save_profile(profile)

    return profile