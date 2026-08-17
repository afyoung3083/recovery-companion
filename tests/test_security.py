from app.security import (
    REDACTED,
    redact_sensitive_text,
)


def test_redacts_explicit_secret():
    secret = "super-secret-value"

    result = redact_sensitive_text(
        f"Failure using {secret}",
        secrets=[secret],
    )

    assert secret not in result
    assert REDACTED in result


def test_redacts_bearer_token():
    result = redact_sensitive_text(
        "Authorization: Bearer abc.def-123"
    )

    assert "abc.def-123" not in result
    assert f"Bearer {REDACTED}" in result


def test_redacts_openai_style_key():
    result = redact_sensitive_text(
        "Key was sk-example1234567890"
    )

    assert "sk-example1234567890" not in result
    assert REDACTED in result


def test_redacts_generic_api_key_assignment():
    result = redact_sensitive_text(
        "api_key=my-secret-api-token"
    )

    assert "my-secret-api-token" not in result
    assert f"api_key={REDACTED}" in result


def test_preserves_non_sensitive_text():
    text = "Connection timed out while contacting service."

    result = redact_sensitive_text(text)

    assert result == text