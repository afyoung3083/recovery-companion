from pathlib import Path
import re


PROJECT_ROOT = Path(
    __file__
).resolve().parent.parent


def source(
    relative_path: str,
) -> str:
    return (
        PROJECT_ROOT
        / relative_path
    ).read_text(
        encoding="utf-8"
    )


def test_render_uses_python_312():
    assert (
        source(".python-version").strip()
        == "3.12"
    )


def test_render_blueprint_runs_narrow_production_app():
    blueprint = source("render.yaml")

    required = (
        "type: web",
        "name: recovery-companion-api",
        "runtime: python",
        "plan: 0.5c-512mb",
        "region: virginia",
        "branch: main",
        "numInstances: 1",
        (
            "python -m uvicorn "
            "app.production_api:app"
        ),
        "--host 0.0.0.0",
        "--port $PORT",
        "--workers 1",
        "--no-access-log",
        "--no-server-header",
        "healthCheckPath: /health",
        "autoDeployTrigger: checksPass",
    )

    for token in required:
        assert token in blueprint

    assert "app.api:app" not in blueprint
    assert "disk:" not in blueprint
    assert "databases:" not in blueprint


def test_render_blueprint_does_not_hardcode_secrets():
    blueprint = source("render.yaml")

    for secret_name in (
        "OPENAI_API_KEY",
        "RECOVERY_API_TOKEN",
    ):
        pattern = (
            rf"- key: {secret_name}\s+"
            r"sync: false"
        )

        assert re.search(
            pattern,
            blueprint,
        )

    assert "sk-" not in blueprint
    assert "Bearer " not in blueprint


def test_render_blueprint_sets_guardrails():
    blueprint = source("render.yaml")

    required = (
        "RECOVERY_ENVIRONMENT",
        "value: production",
        "RECOVERY_MAX_REQUEST_BYTES",
        'value: "65536"',
        "RECOVERY_RATE_LIMIT_REQUESTS",
        'value: "30"',
        (
            "RECOVERY_RATE_LIMIT_WINDOW_SECONDS"
        ),
        'value: "60"',
    )

    for token in required:
        assert token in blueprint


def test_backend_ci_runs_on_pull_requests_and_main():
    workflow = source(
        ".github/workflows/backend-ci.yml"
    )

    required = (
        "pull_request:",
        "push:",
        "branches:",
        "- main",
        "workflow_dispatch:",
        "permissions:",
        "contents: read",
        "actions/checkout@v6",
        "actions/setup-python@v6",
        'python-version: "3.12"',
        "tests/test_production_api.py",
        (
            "tests/"
            "test_render_blueprint_contract.py"
        ),
        "python -m pytest",
    )

    for token in required:
        assert token in workflow


def test_production_api_has_only_explicit_ai_contracts():
    production_api = source(
        "app/production_api.py"
    )

    required_routes = (
        '"/health"',
        '"/chat"',
        (
            '"/recovery-insights/'
            'ai-reflection"'
        ),
        (
            '"/daily-checkin/'
            'ai-reflection"'
        ),
        (
            '"/journal/{entry_id}/'
            'ai-reflection"'
        ),
        (
            '"/weekly-review/'
            'ai-reflection"'
        ),
        (
            '"/monthly-review/'
            'ai-reflection"'
        ),
    )

    for route in required_routes:
        assert route in production_api

    forbidden_imports = (
        "from app.journal import",
        "from app.goals import",
        "from app.routines import",
        "from app.fellowship import",
        "from app.profile import",
        "from app.step_work import",
        "from app.sync import",
        "from app.backup import",
        "from app.data_ownership import",
        "open(",
        "write_text(",
        "write_bytes(",
    )

    for token in forbidden_imports:
        assert token not in production_api

    assert "docs_url=None" in production_api
    assert "redoc_url=None" in production_api
    assert "openapi_url=None" in production_api
    assert 'extra="forbid"' in production_api


def test_security_module_avoids_content_logging():
    security = source(
        "app/production_security.py"
    )

    assert "import logging" not in security
    assert "print(" not in security
    assert "request.body" not in security

    required = (
        "hmac.compare_digest",
        "RequestBodyLimitMiddleware",
        "SlidingWindowRateLimiter",
        "Cache-Control",
        "no-store",
        "sha256",
    )

    for token in required:
        assert token in security


def test_runbook_does_not_claim_service_is_live():
    runbook = source(
        "docs/production-ai-backend.md"
    )

    required = (
        (
            "deployment readiness only"
        ),
        (
            "do not mean the\n"
            "production service is live"
        ),
        "app.production_api:app",
        "It must not run:",
        "app.api:app",
        "api.recoverycompanionlabs.com",
        (
            "The current Google Play build "
            "remains unchanged by Slice 1."
        ),
    )

    for token in required:
        assert token in runbook
