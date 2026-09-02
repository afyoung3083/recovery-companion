from __future__ import annotations

from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient

from app.production_api import (
    MAX_AI_TEXT_CHARACTERS,
    create_production_app,
)
from app.production_security import (
    ProductionConfigurationError,
    SlidingWindowRateLimiter,
)
from app.version import __version__


TEST_TOKEN = "beta-token-" + ("x" * 40)


def configure_valid_environment(
    monkeypatch,
    *,
    max_request_bytes: int = 65_536,
    rate_limit_requests: int = 30,
    rate_limit_window_seconds: int = 60,
) -> None:
    monkeypatch.setenv(
        "RECOVERY_ENVIRONMENT",
        "production",
    )

    monkeypatch.setenv(
        "OPENAI_API_KEY",
        "test-openai-key-not-for-production",
    )

    monkeypatch.setenv(
        "RECOVERY_API_TOKEN",
        TEST_TOKEN,
    )

    monkeypatch.setenv(
        "RECOVERY_MAX_REQUEST_BYTES",
        str(max_request_bytes),
    )

    monkeypatch.setenv(
        "RECOVERY_RATE_LIMIT_REQUESTS",
        str(rate_limit_requests),
    )

    monkeypatch.setenv(
        "RECOVERY_RATE_LIMIT_WINDOW_SECONDS",
        str(rate_limit_window_seconds),
    )


def authorization_headers() -> dict[str, str]:
    return {
        "Authorization": (
            f"Bearer {TEST_TOKEN}"
        ),
    }


def make_app(
    monkeypatch,
    *,
    chat_handler: Callable[
        [list[dict[str, str]]],
        str,
    ] = lambda _conversation: "chat response",
    recovery_insights_handler: Callable[
        [str],
        str,
    ] = lambda _text: "insights reflection",
    daily_checkin_handler: Callable[
        [str],
        str,
    ] = lambda _text: "check-in reflection",
    journal_handler: Callable[
        [str],
        str,
    ] = lambda _text: "journal reflection",
    weekly_review_handler: Callable[
        [str],
        str,
    ] = lambda _text: "weekly reflection",
    monthly_review_handler: Callable[
        [str],
        str,
    ] = lambda _text: "monthly reflection",
    rate_limiter: SlidingWindowRateLimiter
    | None = None,
):
    configure_valid_environment(
        monkeypatch
    )

    return create_production_app(
        chat_handler=chat_handler,
        recovery_insights_handler=(
            recovery_insights_handler
        ),
        daily_checkin_handler=(
            daily_checkin_handler
        ),
        journal_handler=journal_handler,
        weekly_review_handler=(
            weekly_review_handler
        ),
        monthly_review_handler=(
            monthly_review_handler
        ),
        rate_limiter=rate_limiter,
    )


def test_startup_requires_production_environment(
    monkeypatch,
):
    monkeypatch.delenv(
        "RECOVERY_ENVIRONMENT",
        raising=False,
    )

    monkeypatch.setenv(
        "OPENAI_API_KEY",
        "test-openai-key",
    )

    monkeypatch.setenv(
        "RECOVERY_API_TOKEN",
        TEST_TOKEN,
    )

    application = (
        create_production_app()
    )

    with pytest.raises(
        ProductionConfigurationError,
        match="RECOVERY_ENVIRONMENT",
    ):
        with TestClient(application):
            pass


def test_startup_requires_openai_key(
    monkeypatch,
):
    monkeypatch.setenv(
        "RECOVERY_ENVIRONMENT",
        "production",
    )

    monkeypatch.delenv(
        "OPENAI_API_KEY",
        raising=False,
    )

    monkeypatch.setenv(
        "RECOVERY_API_TOKEN",
        TEST_TOKEN,
    )

    application = (
        create_production_app()
    )

    with pytest.raises(
        ProductionConfigurationError,
        match="OPENAI_API_KEY",
    ):
        with TestClient(application):
            pass


def test_startup_rejects_short_beta_token(
    monkeypatch,
):
    monkeypatch.setenv(
        "RECOVERY_ENVIRONMENT",
        "production",
    )

    monkeypatch.setenv(
        "OPENAI_API_KEY",
        "test-openai-key",
    )

    monkeypatch.setenv(
        "RECOVERY_API_TOKEN",
        "too-short",
    )

    application = (
        create_production_app()
    )

    with pytest.raises(
        ProductionConfigurationError,
        match="RECOVERY_API_TOKEN",
    ):
        with TestClient(application):
            pass


def test_route_surface_is_ai_only(
    monkeypatch,
):
    application = make_app(
        monkeypatch
    )

    actual = {
        (
            route.path,
            method,
        )
        for route in application.routes
        for method in route.methods
    }

    assert actual == {
        ("/health", "GET"),
        ("/chat", "POST"),
        (
            "/recovery-insights/ai-reflection",
            "POST",
        ),
        (
            "/daily-checkin/ai-reflection",
            "POST",
        ),
        (
            "/journal/{entry_id}/ai-reflection",
            "POST",
        ),
        (
            "/weekly-review/ai-reflection",
            "POST",
        ),
        (
            "/monthly-review/ai-reflection",
            "POST",
        ),
    }


def test_health_is_public_hardened_and_docs_are_disabled(
    monkeypatch,
):
    application = make_app(
        monkeypatch
    )

    with TestClient(application) as client:
        response = client.get(
            "/health"
        )

        assert response.status_code == 200

        assert response.json() == {
            "status": "ok",
            "service": (
                "recovery-companion-ai"
            ),
            "version": __version__,
        }

        assert (
            response.headers[
                "cache-control"
            ]
            == "no-store"
        )

        assert (
            response.headers[
                "x-content-type-options"
            ]
            == "nosniff"
        )

        assert (
            client.get("/docs").status_code
            == 404
        )

        assert (
            client.get(
                "/openapi.json"
            ).status_code
            == 404
        )


def test_protected_routes_require_matching_bearer_token(
    monkeypatch,
):
    application = make_app(
        monkeypatch
    )

    payload = {
        "conversation": [
            {
                "role": "user",
                "content": "Hello.",
            },
        ],
    }

    with TestClient(application) as client:
        missing = client.post(
            "/chat",
            json=payload,
        )

        invalid = client.post(
            "/chat",
            headers={
                "Authorization":
                    "Bearer incorrect-token",
            },
            json=payload,
        )

        valid = client.post(
            "/chat",
            headers=authorization_headers(),
            json=payload,
        )

    assert missing.status_code == 401
    assert invalid.status_code == 401
    assert valid.status_code == 200


def test_chat_forwards_only_validated_conversation(
    monkeypatch,
):
    captured: list[
        list[dict[str, str]]
    ] = []

    def handler(
        conversation: list[
            dict[str, str]
        ],
    ) -> str:
        captured.append(conversation)

        return "Stay connected today."

    application = make_app(
        monkeypatch,
        chat_handler=handler,
    )

    with TestClient(application) as client:
        response = client.post(
            "/chat",
            headers=authorization_headers(),
            json={
                "conversation": [
                    {
                        "role": " USER ",
                        "content":
                            "  I feel isolated.  ",
                    },
                    {
                        "role": "assistant",
                        "content":
                            "Who can you contact?",
                    },
                    {
                        "role": "user",
                        "content":
                            "  My sponsor.  ",
                    },
                ],
            },
        )

    assert response.status_code == 200

    assert response.json() == {
        "response":
            "Stay connected today.",
    }

    assert captured == [
        [
            {
                "role": "user",
                "content":
                    "I feel isolated.",
            },
            {
                "role": "assistant",
                "content":
                    "Who can you contact?",
            },
            {
                "role": "user",
                "content":
                    "My sponsor.",
            },
        ]
    ]


def test_reflection_routes_forward_exact_explicit_text(
    monkeypatch,
):
    captured: dict[str, str] = {}

    def capture(
        name: str,
    ) -> Callable[[str], str]:
        def handler(
            text: str,
        ) -> str:
            captured[name] = text
            return f"{name} response"

        return handler

    application = make_app(
        monkeypatch,
        recovery_insights_handler=capture(
            "insights"
        ),
        daily_checkin_handler=capture(
            "checkin"
        ),
        journal_handler=capture(
            "journal"
        ),
        weekly_review_handler=capture(
            "weekly"
        ),
        monthly_review_handler=capture(
            "monthly"
        ),
    )

    with TestClient(application) as client:
        responses = [
            client.post(
                "/recovery-insights/ai-reflection",
                headers=authorization_headers(),
                json={
                    "summary":
                        "  INSIGHTS SUMMARY  ",
                },
            ),
            client.post(
                "/daily-checkin/ai-reflection",
                headers=authorization_headers(),
                json={
                    "summary":
                        "  CHECKIN SUMMARY  ",
                    "checkin_count": 7,
                },
            ),
            client.post(
                "/journal/37/ai-reflection",
                headers=authorization_headers(),
                json={
                    "text":
                        "  EXACT JOURNAL ENTRY  ",
                },
            ),
            client.post(
                "/weekly-review/ai-reflection",
                headers=authorization_headers(),
                json={
                    "summary":
                        "  WEEKLY SUMMARY  ",
                },
            ),
            client.post(
                "/monthly-review/ai-reflection",
                headers=authorization_headers(),
                json={
                    "summary":
                        "  MONTHLY SUMMARY  ",
                },
            ),
        ]

    assert all(
        response.status_code == 200
        for response in responses
    )

    assert captured == {
        "insights": "INSIGHTS SUMMARY",
        "checkin": "CHECKIN SUMMARY",
        "journal": "EXACT JOURNAL ENTRY",
        "weekly": "WEEKLY SUMMARY",
        "monthly": "MONTHLY SUMMARY",
    }

    assert responses[1].json()[
        "checkin_count"
    ] == 7

    assert responses[2].json()[
        "entry_id"
    ] == 37


@pytest.mark.parametrize(
    "path",
    [
        (
            "/recovery-insights/"
            "ai-reflection"
        ),
        "/daily-checkin/ai-reflection",
        "/journal/1/ai-reflection",
        "/weekly-review/ai-reflection",
        "/monthly-review/ai-reflection",
    ],
)
def test_reflection_routes_require_explicit_body(
    monkeypatch,
    path,
):
    application = make_app(
        monkeypatch
    )

    with TestClient(application) as client:
        response = client.post(
            path,
            headers=authorization_headers(),
        )

    assert response.status_code == 422

    assert response.json() == {
        "detail": "Invalid request.",
    }


def test_validation_response_does_not_echo_sensitive_input(
    monkeypatch,
):
    application = make_app(
        monkeypatch
    )

    private_text = (
        "PRIVATE RECOVERY DETAIL"
    )

    with TestClient(application) as client:
        response = client.post(
            "/weekly-review/ai-reflection",
            headers=authorization_headers(),
            json={
                "summary": private_text,
                "unexpected": private_text,
            },
        )

    assert response.status_code == 422

    serialized = response.text

    assert private_text not in serialized

    assert response.json() == {
        "detail": "Invalid request.",
    }


def test_request_body_limit_rejects_oversized_payload(
    monkeypatch,
):
    configure_valid_environment(
        monkeypatch,
        max_request_bytes=1_024,
    )

    application = (
        create_production_app()
    )

    with TestClient(application) as client:
        response = client.post(
            "/chat",
            headers=authorization_headers(),
            json={
                "conversation": [
                    {
                        "role": "user",
                        "content":
                            "x" * 2_000,
                    },
                ],
            },
        )

    assert response.status_code == 413

    assert response.json() == {
        "detail":
            "Request body is too large.",
    }

    assert (
        response.headers[
            "cache-control"
        ]
        == "no-store"
    )


def test_rate_limit_returns_retry_after(
    monkeypatch,
):
    configure_valid_environment(
        monkeypatch,
        rate_limit_requests=2,
        rate_limit_window_seconds=60,
    )

    limiter = SlidingWindowRateLimiter(
        limit=2,
        window_seconds=60,
        clock=lambda: 100.0,
    )

    provider_calls = 0

    def deterministic_chat_handler(
        _conversation: list[dict[str, str]],
    ) -> str:
        nonlocal provider_calls

        provider_calls += 1

        return "rate-limit test response"

    application = create_production_app(
        chat_handler=deterministic_chat_handler,
        rate_limiter=limiter,
    )

    payload = {
        "conversation": [
            {
                "role": "user",
                "content": "Hello.",
            },
        ],
    }

    with TestClient(application) as client:
        first = client.post(
            "/chat",
            headers=authorization_headers(),
            json=payload,
        )

        second = client.post(
            "/chat",
            headers=authorization_headers(),
            json=payload,
        )

        blocked = client.post(
            "/chat",
            headers=authorization_headers(),
            json=payload,
        )

    assert first.status_code == 200
    assert second.status_code == 200
    assert blocked.status_code == 429
    assert blocked.headers["retry-after"] == "60"

    # Only the first two permitted requests may reach the
    # simulated AI provider. The blocked request must stop
    # at the rate limiter.
    assert provider_calls == 2


def test_provider_failure_is_sanitized(
    monkeypatch,
):
    private_provider_error = (
        "provider-secret-diagnostic"
    )

    def fail(
        _text: str,
    ) -> str:
        raise RuntimeError(
            private_provider_error
        )

    application = make_app(
        monkeypatch,
        journal_handler=fail,
    )

    with TestClient(application) as client:
        response = client.post(
            "/journal/1/ai-reflection",
            headers=authorization_headers(),
            json={
                "text":
                    "Private journal entry.",
            },
        )

    assert response.status_code == 502
    assert private_provider_error not in response.text
    assert "Private journal entry" not in response.text


def test_ai_text_limit_is_enforced_without_echo(
    monkeypatch,
):
    application = make_app(
        monkeypatch
    )

    oversized = (
        "SENSITIVE"
        * (MAX_AI_TEXT_CHARACTERS // 9 + 1)
    )

    with TestClient(application) as client:
        response = client.post(
            "/journal/1/ai-reflection",
            headers=authorization_headers(),
            json={
                "text": oversized,
            },
        )

    assert response.status_code in {
        413,
        422,
    }

    assert "SENSITIVE" not in response.text
