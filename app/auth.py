from fastapi import Header, HTTPException, status

from app.config import RECOVERY_API_TOKEN


def require_api_token(
    authorization: str | None = Header(
        default=None
    ),
) -> None:
    """
    Require a valid Bearer token for protected API endpoints.

    This is a temporary local authentication foundation for
    development. It can later be replaced by a production identity
    provider without changing every endpoint.
    """

    if not RECOVERY_API_TOKEN:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="API authentication is not configured.",
        )

    expected = (
        f"Bearer {RECOVERY_API_TOKEN}"
    )

    if authorization != expected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API token.",
            headers={
                "WWW-Authenticate": "Bearer",
            },
        )