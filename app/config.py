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

# Local development may use a project-root .env file.
# In CI, production, or containers, values may instead come
# directly from environment variables.
load_dotenv(ENV_FILE)


# ============================================================
# OpenAI configuration
# ============================================================

OPENAI_API_KEY = os.getenv(
    "OPENAI_API_KEY",
    "",
).strip()

MODEL_NAME = "gpt-5"


# ============================================================
# Recovery Companion API authentication
# ============================================================

RECOVERY_API_TOKEN = os.getenv(
    "RECOVERY_API_TOKEN",
    "",
).strip()