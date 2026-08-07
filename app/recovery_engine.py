from app.ai_client import generate_response
from app.config import PROMPT_FILE


def load_system_prompt() -> str:
    if not PROMPT_FILE.exists():
        raise FileNotFoundError(f"Prompt file not found: {PROMPT_FILE}")

    return PROMPT_FILE.read_text(encoding="utf-8").strip()


def respond_to_user(
    conversation: list[dict[str, str]],
) -> str:
    system_prompt = load_system_prompt()
    return generate_response(conversation, system_prompt)