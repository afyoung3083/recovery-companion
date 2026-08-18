from typing import Any, TypeAlias

from openai import OpenAI

from app.config import MODEL_NAME, OPENAI_API_KEY


# ============================================================
# Types
# ============================================================

# Recovery Companion currently passes ordinary OpenAI message-style
# dictionaries between the application and the AI client.
Conversation: TypeAlias = list[dict[str, str]]


# ============================================================
# Lazy OpenAI client
# ============================================================

# Do not create the OpenAI client when this module is imported.
#
# This is important for:
# - pytest collection
# - GitHub Actions
# - CLI features that do not use AI
# - API endpoints that do not use AI
#
# Those parts of Recovery Companion should work even when an
# OPENAI_API_KEY has not been configured.
_openai_client: OpenAI | None = None


def get_client() -> OpenAI:
    """
    Return the reusable OpenAI client, creating it only when needed.

    The API key is therefore required only when an AI feature is
    actually invoked rather than whenever app.ai_client is imported.
    """

    global _openai_client

    if _openai_client is not None:
        return _openai_client

    if not OPENAI_API_KEY:
        raise RuntimeError(
            "OPENAI_API_KEY is not configured. "
            "Add it to the project .env file or environment "
            "before using AI features."
        )

    _openai_client = OpenAI(
        api_key=OPENAI_API_KEY,
    )

    return _openai_client


# ============================================================
# Backward-compatible client proxy
# ============================================================

class _LazyOpenAIClient:
    """
    Preserve the existing ``client.responses...`` interface.

    Some Recovery Companion modules, including the RKS grader, use
    ``client.responses.create(...)`` directly. This small proxy keeps
    that interface intact while delaying real OpenAI client creation
    until an OpenAI operation is actually requested.
    """

    @property
    def responses(self) -> Any:
        """Return the real client's Responses API resource."""

        return get_client().responses


# Public compatibility object.
#
# Importing this object is safe without an API key. Accessing
# client.responses will initialize the real OpenAI client.
client = _LazyOpenAIClient()


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
    ``store=False`` prevents the response from being stored for
    later retrieval through the Responses API.

    OpenAI/API exceptions intentionally propagate to higher layers,
    where Recovery Companion can sanitize and display them safely.
    """

    response = get_client().responses.create(
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