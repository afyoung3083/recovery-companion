from typing import TypeAlias

from openai import OpenAI

from app.config import MODEL_NAME, OPENAI_API_KEY


# ============================================================
# Types
# ============================================================

# Recovery Companion currently passes ordinary OpenAI message-style
# dictionaries between the CLI and the AI client.
Conversation: TypeAlias = list[dict[str, str]]


# ============================================================
# OpenAI client
# ============================================================

# Create one reusable OpenAI client for the application.
#
# OPENAI_API_KEY is loaded and validated by app.config, so this
# module does not need to read environment variables directly.
client = OpenAI(
    api_key=OPENAI_API_KEY,
)


# ============================================================
# Response generation
# ============================================================

def generate_response(
    conversation: Conversation,
    instructions: str,
) -> str:
    """
    Generate a text response using the OpenAI Responses API.

    Parameters
    ----------
    conversation:
        Conversation messages supplied to the model.

    instructions:
        Recovery-specific instructions that guide the model's
        behavior for this request.

    Returns
    -------
    str
        The model's aggregated text response.

    Notes
    -----
    store=False prevents this API response from being stored for
    later retrieval through the Responses API.

    OpenAI/API exceptions are intentionally allowed to propagate.
    Higher application layers can decide how to display or handle
    those failures.
    """

    response = client.responses.create(
        model=MODEL_NAME,
        instructions=instructions,
        input=conversation,
        store=False,
    )

    output_text = response.output_text

    if not output_text:
        raise RuntimeError(
            "OpenAI returned a response without text output."
        )

    return output_text