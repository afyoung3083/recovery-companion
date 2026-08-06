import os
from pathlib import Path

from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_ROOT / ".env"
PROMPT_FILE = PROJECT_ROOT / "prompts" / "system_prompt.md"

load_dotenv(ENV_FILE)

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
MODEL_NAME = "gpt-5"

if not OPENAI_API_KEY:
    raise RuntimeError(
        "OPENAI_API_KEY was not found. Check the .env file in the project root."
    )