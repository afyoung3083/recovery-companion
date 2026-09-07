from unittest.mock import MagicMock, patch

from app.ai_client import generate_response
from app.config import MODEL_NAME


def _mock_client_returning(text: str) -> MagicMock:
    client = MagicMock()
    client.responses.create.return_value = MagicMock(output_text=text)
    return client


def test_generate_response_without_overrides_omits_reasoning_and_text():
    client = _mock_client_returning("hello")

    with patch("app.ai_client.get_client", return_value=client):
        result = generate_response(
            conversation=[{"role": "user", "content": "hi"}],
            instructions="Be kind.",
        )

    assert result == "hello"

    kwargs = client.responses.create.call_args.kwargs

    assert "reasoning" not in kwargs
    assert "text" not in kwargs


def test_generate_response_applies_reasoning_effort_when_supplied():
    client = _mock_client_returning("hello")

    with patch("app.ai_client.get_client", return_value=client):
        generate_response(
            conversation=[{"role": "user", "content": "hi"}],
            instructions="Be kind.",
            reasoning_effort="low",
        )

    kwargs = client.responses.create.call_args.kwargs

    assert kwargs["reasoning"] == {"effort": "low"}
    assert "text" not in kwargs


def test_generate_response_applies_verbosity_when_supplied():
    client = _mock_client_returning("hello")

    with patch("app.ai_client.get_client", return_value=client):
        generate_response(
            conversation=[{"role": "user", "content": "hi"}],
            instructions="Be kind.",
            verbosity="low",
        )

    kwargs = client.responses.create.call_args.kwargs

    assert kwargs["text"] == {"verbosity": "low"}
    assert "reasoning" not in kwargs


def test_generate_response_always_uses_configured_model_and_store_false():
    client = _mock_client_returning("hello")

    with patch("app.ai_client.get_client", return_value=client):
        generate_response(
            conversation=[{"role": "user", "content": "hi"}],
            instructions="Be kind.",
            reasoning_effort="low",
            verbosity="low",
        )

    kwargs = client.responses.create.call_args.kwargs

    assert kwargs["model"] == MODEL_NAME
    assert MODEL_NAME == "gpt-5"
    assert kwargs["store"] is False
