from __future__ import annotations

from collections.abc import Callable
from contextlib import asynccontextmanager
from typing import Any

from fastapi import Depends, FastAPI, HTTPException, Path, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.production_security import (
    DEFAULT_MAX_REQUEST_BYTES,
    DEFAULT_RATE_LIMIT_REQUESTS,
    DEFAULT_RATE_LIMIT_WINDOW_SECONDS,
    RequestBodyLimitMiddleware,
    SecurityHeadersMiddleware,
    SlidingWindowRateLimiter,
    build_production_access_dependency,
    read_bounded_environment_int,
    validate_production_environment,
)
from app.recovery_engine import (
    analyze_checkin_trends,
    analyze_journal_entry,
    analyze_monthly_review,
    analyze_recovery_insights,
    analyze_weekly_review,
    respond_to_user,
)
from app.version import __version__


MAX_AI_TEXT_CHARACTERS = 20_000
MAX_CHAT_MESSAGES = 30
MAX_CHAT_MESSAGE_CHARACTERS = 6_000
MAX_CHAT_TOTAL_CHARACTERS = 30_000

TextHandler = Callable[[str], str]
ChatHandler = Callable[[list[dict[str, str]]], str]


class StrictRequestModel(BaseModel):
    """Reject unexpected fields at the production API boundary."""

    model_config = ConfigDict(
        extra="forbid",
    )


class SummaryRequest(StrictRequestModel):
    summary: str = Field(
        min_length=1,
        max_length=MAX_AI_TEXT_CHARACTERS,
    )

    @field_validator(
        "summary",
        mode="before",
    )
    @classmethod
    def normalize_summary(
        cls,
        value: Any,
    ) -> Any:
        if isinstance(value, str):
            return value.strip()

        return value


class DailyCheckInReflectionRequest(
    SummaryRequest
):
    checkin_count: int = Field(
        default=0,
        ge=0,
        le=31,
    )


class JournalReflectionRequest(
    StrictRequestModel
):
    text: str = Field(
        min_length=1,
        max_length=MAX_AI_TEXT_CHARACTERS,
    )

    @field_validator(
        "text",
        mode="before",
    )
    @classmethod
    def normalize_text(
        cls,
        value: Any,
    ) -> Any:
        if isinstance(value, str):
            return value.strip()

        return value


class ChatMessageRequest(
    StrictRequestModel
):
    role: str = Field(
        min_length=1,
        max_length=9,
    )

    content: str = Field(
        min_length=1,
        max_length=MAX_CHAT_MESSAGE_CHARACTERS,
    )

    @field_validator(
        "role",
        mode="before",
    )
    @classmethod
    def normalize_role(
        cls,
        value: Any,
    ) -> Any:
        if isinstance(value, str):
            return value.strip().lower()

        return value

    @field_validator(
        "content",
        mode="before",
    )
    @classmethod
    def normalize_content(
        cls,
        value: Any,
    ) -> Any:
        if isinstance(value, str):
            return value.strip()

        return value


class ChatRequest(StrictRequestModel):
    conversation: list[ChatMessageRequest] = Field(
        min_length=1,
        max_length=MAX_CHAT_MESSAGES,
    )


def _run_text_handler(
    handler: TextHandler,
    text: str,
    *,
    failure_detail: str,
) -> str:
    """Run one AI handler without exposing provider exceptions."""

    try:
        result = handler(text).strip()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=failure_detail,
        ) from None

    if not result:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=failure_detail,
        )

    return result


def _validated_conversation(
    request: ChatRequest,
) -> list[dict[str, str]]:
    """Validate role order and cap the total transmitted chat text."""

    conversation: list[dict[str, str]] = []
    previous_role: str | None = None
    total_characters = 0

    for message in request.conversation:
        role = message.role

        if role not in {
            "user",
            "assistant",
        }:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Chat message role must be "
                    "user or assistant."
                ),
            )

        if previous_role == role:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Chat message roles must alternate."
                ),
            )

        total_characters += len(
            message.content
        )

        if (
            total_characters
            > MAX_CHAT_TOTAL_CHARACTERS
        ):
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=(
                    "Chat conversation is too large."
                ),
            )

        conversation.append(
            {
                "role": role,
                "content": message.content,
            }
        )

        previous_role = role

    if conversation[0]["role"] != "user":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Conversation must begin "
                "with a user message."
            ),
        )

    if conversation[-1]["role"] != "user":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Conversation must end "
                "with a user message."
            ),
        )

    return conversation


def create_production_app(
    *,
    chat_handler: ChatHandler = respond_to_user,
    recovery_insights_handler: TextHandler = (
        analyze_recovery_insights
    ),
    daily_checkin_handler: TextHandler = (
        analyze_checkin_trends
    ),
    journal_handler: TextHandler = (
        analyze_journal_entry
    ),
    weekly_review_handler: TextHandler = (
        analyze_weekly_review
    ),
    monthly_review_handler: TextHandler = (
        analyze_monthly_review
    ),
    rate_limiter: SlidingWindowRateLimiter
    | None = None,
) -> FastAPI:
    """
    Build the public, stateless AI-only Recovery Companion API.

    The legacy local-development API remains in app.api. Render must run
    this application instead so server-side recovery CRUD is not exposed.
    """

    max_request_bytes = (
        read_bounded_environment_int(
            "RECOVERY_MAX_REQUEST_BYTES",
            default=DEFAULT_MAX_REQUEST_BYTES,
            minimum=1_024,
            maximum=1_048_576,
        )
    )

    rate_limit_requests = (
        read_bounded_environment_int(
            "RECOVERY_RATE_LIMIT_REQUESTS",
            default=DEFAULT_RATE_LIMIT_REQUESTS,
            minimum=1,
            maximum=1_000,
        )
    )

    rate_limit_window_seconds = (
        read_bounded_environment_int(
            "RECOVERY_RATE_LIMIT_WINDOW_SECONDS",
            default=DEFAULT_RATE_LIMIT_WINDOW_SECONDS,
            minimum=1,
            maximum=3_600,
        )
    )

    limiter = (
        rate_limiter
        or SlidingWindowRateLimiter(
            limit=rate_limit_requests,
            window_seconds=(
                rate_limit_window_seconds
            ),
        )
    )

    require_access = (
        build_production_access_dependency(
            limiter
        )
    )

    @asynccontextmanager
    async def lifespan(
        _: FastAPI,
    ):
        validate_production_environment()
        yield

    production_app = FastAPI(
        title="Recovery Companion AI API",
        version=__version__,
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
        lifespan=lifespan,
    )

    # Add request limiting first and response security second.
    # Starlette places the last added middleware outside earlier entries,
    # so security headers also cover request-size rejection responses.
    production_app.add_middleware(
        RequestBodyLimitMiddleware,
        max_bytes=max_request_bytes,
    )

    production_app.add_middleware(
        SecurityHeadersMiddleware,
    )

    @production_app.exception_handler(
        RequestValidationError
    )
    async def validation_error_handler(
        _request,
        _error,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={
                "detail": "Invalid request.",
            },
        )

    @production_app.exception_handler(
        Exception
    )
    async def unexpected_error_handler(
        _request,
        _error,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=500,
            content={
                "detail": (
                    "The service could not "
                    "complete the request."
                ),
            },
        )

    @production_app.get(
        "/health",
    )
    def health() -> dict[str, str]:
        return {
            "status": "ok",
            "service": (
                "recovery-companion-ai"
            ),
            "version": __version__,
        }

    @production_app.post(
        "/chat",
        dependencies=[
            Depends(require_access)
        ],
    )
    def chat(
        request: ChatRequest,
    ) -> dict[str, str]:
        conversation = (
            _validated_conversation(
                request
            )
        )

        try:
            result = chat_handler(
                conversation
            ).strip()
        except Exception:
            raise HTTPException(
                status_code=(
                    status.HTTP_502_BAD_GATEWAY
                ),
                detail=(
                    "Unable to generate a "
                    "Recovery Companion response."
                ),
            ) from None

        if not result:
            raise HTTPException(
                status_code=(
                    status.HTTP_502_BAD_GATEWAY
                ),
                detail=(
                    "Unable to generate a "
                    "Recovery Companion response."
                ),
            )

        return {
            "response": result,
        }

    @production_app.post(
        "/recovery-insights/ai-reflection",
        dependencies=[
            Depends(require_access)
        ],
    )
    def recovery_insights_reflection(
        request: SummaryRequest,
    ) -> dict[str, str]:
        reflection = _run_text_handler(
            recovery_insights_handler,
            request.summary,
            failure_detail=(
                "Unable to generate Recovery "
                "Insights reflection."
            ),
        )

        return {
            "reflection": reflection,
        }

    @production_app.post(
        "/daily-checkin/ai-reflection",
        dependencies=[
            Depends(require_access)
        ],
    )
    def daily_checkin_reflection(
        request: DailyCheckInReflectionRequest,
    ) -> dict[str, str | int]:
        reflection = _run_text_handler(
            daily_checkin_handler,
            request.summary,
            failure_detail=(
                "Unable to generate check-in "
                "reflection."
            ),
        )

        return {
            "checkin_count": (
                request.checkin_count
            ),
            "reflection": reflection,
        }

    @production_app.post(
        "/journal/{entry_id}/ai-reflection",
        dependencies=[
            Depends(require_access)
        ],
    )
    def journal_reflection(
        request: JournalReflectionRequest,
        entry_id: int = Path(
            ge=1,
        ),
    ) -> dict[str, str | int]:
        reflection = _run_text_handler(
            journal_handler,
            request.text,
            failure_detail=(
                "Unable to generate journal "
                "reflection."
            ),
        )

        return {
            "entry_id": entry_id,
            "reflection": reflection,
        }

    @production_app.post(
        "/weekly-review/ai-reflection",
        dependencies=[
            Depends(require_access)
        ],
    )
    def weekly_review_reflection(
        request: SummaryRequest,
    ) -> dict[str, str]:
        reflection = _run_text_handler(
            weekly_review_handler,
            request.summary,
            failure_detail=(
                "Unable to generate weekly "
                "review reflection."
            ),
        )

        return {
            "reflection": reflection,
        }

    @production_app.post(
        "/monthly-review/ai-reflection",
        dependencies=[
            Depends(require_access)
        ],
    )
    def monthly_review_reflection(
        request: SummaryRequest,
    ) -> dict[str, str]:
        reflection = _run_text_handler(
            monthly_review_handler,
            request.summary,
            failure_detail=(
                "Unable to generate monthly "
                "review reflection."
            ),
        )

        return {
            "reflection": reflection,
        }

    return production_app


app = create_production_app()
