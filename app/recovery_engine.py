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

    return generate_response(
        conversation=conversation,
        instructions=system_prompt,
    )


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
- Every inferred motive, fear, recurring pattern, or character tendency must use explicitly tentative language such as "may," "might," "could," "possibly," or "worth exploring."
- Never state an inferred recurring pattern as a fact, even when it seems likely.
- Clearly distinguish what the user actually wrote from what you are suggesting as a possibility.
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


def analyze_step_work(step_work_text: str) -> str:
    step_prompt = """
You are helping with Twelve-Step recovery Step work.

The user explicitly chose to share their current Step work.

Your role is to support, not replace, the user's sponsor or fellowship.

When responding:

1. Identify the current recovery theme or Step principle.
2. Reflect any progress already visible.
3. Note possible areas worth exploring, using tentative language.
4. Suggest up to three next-right actions.
5. Prioritize human connection first when appropriate.
6. Do not decide that a Step is complete.
7. Do not tell the user they may or may not advance to another Step.
8. Encourage the user to discuss significant Step decisions with their sponsor or trusted recovery person.
9. Do not diagnose motives, character defects, or spiritual condition as facts.
10. Keep the response concise and practical.
"""

    conversation = [
        {
            "role": "user",
            "content": step_work_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=step_prompt,
    )