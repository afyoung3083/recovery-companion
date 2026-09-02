from __future__ import annotations

import hashlib
import hmac
import math
import os
import threading
import time
from collections import deque
from collections.abc import Callable

from fastapi import Header, HTTPException, Request, status
from starlette.datastructures import MutableHeaders
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send


DEFAULT_MAX_REQUEST_BYTES = 65_536
DEFAULT_RATE_LIMIT_REQUESTS = 30
DEFAULT_RATE_LIMIT_WINDOW_SECONDS = 60

MIN_BETA_TOKEN_LENGTH = 32


class ProductionConfigurationError(RuntimeError):
    """Raised when required production settings are absent or invalid."""


class _RequestBodyTooLarge(Exception):
    """Internal signal used by the ASGI request-size middleware."""


def read_bounded_environment_int(
    name: str,
    *,
    default: int,
    minimum: int,
    maximum: int,
) -> int:
    """Read a bounded integer without exposing environment values."""

    raw_value = os.getenv(name, "").strip()

    if not raw_value:
        return default

    try:
        value = int(raw_value)
    except ValueError as error:
        raise ProductionConfigurationError(
            f"{name} must be an integer."
        ) from error

    if value < minimum or value > maximum:
        raise ProductionConfigurationError(
            f"{name} must be between {minimum} and {maximum}."
        )

    return value


def validate_production_environment() -> None:
    """
    Fail service startup when required production configuration is unsafe.

    Secret values are never included in exception messages.
    """

    problems: list[str] = []

    if os.getenv("RECOVERY_ENVIRONMENT", "").strip().lower() != "production":
        problems.append(
            "RECOVERY_ENVIRONMENT must equal production."
        )

    if not os.getenv("OPENAI_API_KEY", "").strip():
        problems.append(
            "OPENAI_API_KEY is required."
        )

    token = os.getenv("RECOVERY_API_TOKEN", "").strip()

    if len(token) < MIN_BETA_TOKEN_LENGTH:
        problems.append(
            "RECOVERY_API_TOKEN must contain at least "
            f"{MIN_BETA_TOKEN_LENGTH} characters."
        )

    read_bounded_environment_int(
        "RECOVERY_MAX_REQUEST_BYTES",
        default=DEFAULT_MAX_REQUEST_BYTES,
        minimum=1_024,
        maximum=1_048_576,
    )

    read_bounded_environment_int(
        "RECOVERY_RATE_LIMIT_REQUESTS",
        default=DEFAULT_RATE_LIMIT_REQUESTS,
        minimum=1,
        maximum=1_000,
    )

    read_bounded_environment_int(
        "RECOVERY_RATE_LIMIT_WINDOW_SECONDS",
        default=DEFAULT_RATE_LIMIT_WINDOW_SECONDS,
        minimum=1,
        maximum=3_600,
    )

    if problems:
        raise ProductionConfigurationError(
            "Production configuration is invalid: "
            + " ".join(problems)
        )


class SlidingWindowRateLimiter:
    """
    Small, process-local closed-beta rate limiter.

    Slice 1 deliberately runs one worker and one service instance so this
    in-memory limiter has one authoritative window. A distributed store is
    required before horizontally scaling the service.
    """

    def __init__(
        self,
        *,
        limit: int,
        window_seconds: int,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._limit = limit
        self._window_seconds = window_seconds
        self._clock = clock
        self._events: dict[str, deque[float]] = {}
        self._lock = threading.Lock()

    def allow(self, key: str) -> tuple[bool, int]:
        """Record an allowed request or return the retry delay."""

        now = self._clock()
        cutoff = now - self._window_seconds

        with self._lock:
            events = self._events.setdefault(
                key,
                deque(),
            )

            while events and events[0] <= cutoff:
                events.popleft()

            if len(events) >= self._limit:
                retry_after = max(
                    1,
                    math.ceil(
                        events[0]
                        + self._window_seconds
                        - now
                    ),
                )

                return False, retry_after

            events.append(now)

            return True, 0


def _client_rate_key(request: Request) -> str:
    """Hash the transport-level client address before storing it in memory."""

    host = (
        request.client.host
        if request.client is not None
        else "unknown"
    )

    return hashlib.sha256(
        host.encode("utf-8")
    ).hexdigest()


def build_production_access_dependency(
    limiter: SlidingWindowRateLimiter,
):
    """Build the temporary closed-beta bearer-token dependency."""

    async def require_production_access(
        request: Request,
        authorization: str | None = Header(
            default=None
        ),
    ) -> None:
        expected_token = os.getenv(
            "RECOVERY_API_TOKEN",
            "",
        ).strip()

        if len(expected_token) < MIN_BETA_TOKEN_LENGTH:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=(
                    "API authentication is not configured."
                ),
            )

        supplied_token = ""

        if authorization:
            scheme, separator, credential = (
                authorization.partition(" ")
            )

            if (
                separator
                and scheme.lower() == "bearer"
            ):
                supplied_token = credential.strip()

        if (
            not supplied_token
            or not hmac.compare_digest(
                supplied_token,
                expected_token,
            )
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=(
                    "Invalid or missing API token."
                ),
                headers={
                    "WWW-Authenticate": "Bearer",
                },
            )

        allowed, retry_after = limiter.allow(
            _client_rate_key(request)
        )

        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=(
                    "Too many AI requests. "
                    "Please wait and try again."
                ),
                headers={
                    "Retry-After": str(retry_after),
                },
            )

    return require_production_access


class RequestBodyLimitMiddleware:
    """Reject declared or streamed request bodies above the configured limit."""

    def __init__(
        self,
        app: ASGIApp,
        *,
        max_bytes: int,
    ) -> None:
        self._app = app
        self._max_bytes = max_bytes

    async def __call__(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        if scope["type"] != "http":
            await self._app(
                scope,
                receive,
                send,
            )
            return

        headers = dict(
            scope.get("headers", [])
        )

        content_length = headers.get(
            b"content-length"
        )

        if content_length is not None:
            try:
                declared_length = int(
                    content_length.decode(
                        "ascii"
                    )
                )
            except (
                UnicodeDecodeError,
                ValueError,
            ):
                await self._send_error(
                    scope,
                    receive,
                    send,
                    status_code=400,
                    detail=(
                        "Invalid Content-Length header."
                    ),
                )
                return

            if declared_length < 0:
                await self._send_error(
                    scope,
                    receive,
                    send,
                    status_code=400,
                    detail=(
                        "Invalid Content-Length header."
                    ),
                )
                return

            if declared_length > self._max_bytes:
                await self._send_error(
                    scope,
                    receive,
                    send,
                    status_code=413,
                    detail=(
                        "Request body is too large."
                    ),
                )
                return

        received_bytes = 0
        response_started = False

        async def limited_receive() -> Message:
            nonlocal received_bytes

            message = await receive()

            if message["type"] == "http.request":
                received_bytes += len(
                    message.get("body", b"")
                )

                if received_bytes > self._max_bytes:
                    raise _RequestBodyTooLarge

            return message

        async def tracked_send(
            message: Message,
        ) -> None:
            nonlocal response_started

            if (
                message["type"]
                == "http.response.start"
            ):
                response_started = True

            await send(message)

        try:
            await self._app(
                scope,
                limited_receive,
                tracked_send,
            )
        except _RequestBodyTooLarge:
            if response_started:
                raise

            await self._send_error(
                scope,
                receive,
                send,
                status_code=413,
                detail=(
                    "Request body is too large."
                ),
            )

    @staticmethod
    async def _send_error(
        scope: Scope,
        receive: Receive,
        send: Send,
        *,
        status_code: int,
        detail: str,
    ) -> None:
        response = JSONResponse(
            status_code=status_code,
            content={
                "detail": detail,
            },
        )

        await response(
            scope,
            receive,
            send,
        )


class SecurityHeadersMiddleware:
    """Add no-store and browser hardening headers to every API response."""

    def __init__(
        self,
        app: ASGIApp,
    ) -> None:
        self._app = app

    async def __call__(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        if scope["type"] != "http":
            await self._app(
                scope,
                receive,
                send,
            )
            return

        async def send_with_headers(
            message: Message,
        ) -> None:
            if (
                message["type"]
                == "http.response.start"
            ):
                headers = MutableHeaders(
                    scope=message
                )

                headers["Cache-Control"] = (
                    "no-store"
                )

                headers["Pragma"] = "no-cache"

                headers[
                    "X-Content-Type-Options"
                ] = "nosniff"

                headers[
                    "X-Frame-Options"
                ] = "DENY"

                headers[
                    "Referrer-Policy"
                ] = "no-referrer"

                headers[
                    "Content-Security-Policy"
                ] = (
                    "default-src 'none'; "
                    "frame-ancestors 'none'; "
                    "base-uri 'none'"
                )

            await send(message)

        await self._app(
            scope,
            receive,
            send_with_headers,
        )
