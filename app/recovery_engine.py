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

def analyze_journal_entry(entry_text: str) -> str:
    journal_prompt = """
You are analyzing a journal entry for a Twelve-Step recovery companion.

The user explicitly chose to share this entry for analysis.

Identify, with humility and without diagnosis:

1. Recovery themes
2. Possible recurring patterns
3. Victories or evidence of progress
4. Items worth discussing with a sponsor or trusted recovery person
5. Up to three next-right actions, ranked by:
   - human connection
   - Higher Power connection
   - current Step work
   - service
   - journaling
   - amends

Rules:
- Do not claim certainty about motives, character defects, or spiritual condition.
- Use language such as "may," "might," or "could be worth exploring."
- Do not shame.
- Do not treat the journal entry as a clinical record.
- Keep the response concise.
"""

    conversation = [
        {
            "role": "user",
            "content": entry_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=journal_prompt,
    )