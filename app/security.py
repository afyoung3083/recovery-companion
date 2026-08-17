import re


# ============================================================
# Sensitive-value redaction
# ============================================================

REDACTED = "[REDACTED]"


def redact_sensitive_text(
    text: str,
    secrets: list[str] | None = None,
) -> str:
    """
    Remove likely secrets from text before displaying an error.

    Explicit application secrets can be supplied through ``secrets``.
    Common API-key and authorization-token patterns are also masked.

    This is defensive output sanitization; it does not replace secure
    secret storage.
    """

    sanitized = str(text)

    # --------------------------------------------------------
    # Explicit secrets known by the application
    # --------------------------------------------------------

    for secret in secrets or []:
        if secret:
            sanitized = sanitized.replace(
                secret,
                REDACTED,
            )

    # --------------------------------------------------------
    # Common bearer-token formatting
    # --------------------------------------------------------

    sanitized = re.sub(
        r"(?i)(bearer\s+)[A-Za-z0-9._\-]+",
        rf"\1{REDACTED}",
        sanitized,
    )

    # --------------------------------------------------------
    # Common OpenAI-style secret-key formatting
    #
    # Do not depend on an exact key length because key formats
    # may change over time.
    # --------------------------------------------------------

    sanitized = re.sub(
        r"\bsk-[A-Za-z0-9_\-]{10,}\b",
        REDACTED,
        sanitized,
    )

    # --------------------------------------------------------
    # Generic API-key assignments such as:
    #
    # api_key=...
    # api-key: ...
    # api key = ...
    # --------------------------------------------------------

    sanitized = re.sub(
        r"(?i)"
        r"(api[_\-\s]?key\s*[:=]\s*)"
        r"[^\s,;]+",
        rf"\1{REDACTED}",
        sanitized,
    )

    return sanitized