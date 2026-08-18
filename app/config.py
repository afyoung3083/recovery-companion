import os
from pathlib import Path

from dotenv import load_dotenv


# ============================================================
# Application paths
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parent.parent

ENV_FILE = PROJECT_ROOT / ".env"

PROMPT_FILE = (
    PROJECT_ROOT
    / "prompts"
    / "system_prompt.md"
)


# ============================================================
# Environment
# ============================================================

load_dotenv(ENV_FILE)


# ============================================================
# OpenAI configuration
# ============================================================

OPENAI_API_KEY = os.getenv(
    "OPENAI_API_KEY",
    "",
).strip()

MODEL_NAME = "gpt-5"

if not OPENAI_API_KEY:
    raise RuntimeError(
        "OPENAI_API_KEY was not found. "
        "Check the .env file in the project root."
    )


# ============================================================
# Recovery Companion API authentication
# ============================================================

RECOVERY_API_TOKEN = os.getenv(
    "RECOVERY_API_TOKEN",
    "",
).strip()

if not RECOVERY_API_TOKEN:
    raise RuntimeError(
        "RECOVERY_API_TOKEN was not found. "
        "Check the .env file in the project root."
    )