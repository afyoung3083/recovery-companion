from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "insights-ai-test-token"

client = TestClient(app)


@pytest.fixture(autouse=True)
def configure_test_api_token(
    monkeypatch,
):
    monkeypatch.setattr(
        auth_module,
        "RECOVERY_API_TOKEN",
        TEST_API_TOKEN,
    )


def auth_headers() -> dict[str, str]:
    return {
        "Authorization": (
            f"Bearer {TEST_API_TOKEN}"
        ),
    }


@patch("app.api.analyze_recovery_insights")
@patch("app.api.build_recovery_insights")
def test_recovery_insights_ai_analyzes_local_summary(
    mock_build_recovery_insights,
    mock_analyze_recovery_insights,
):
    mock_build_recovery_insights.return_value = (
        "DETERMINISTIC RECOVERY INSIGHTS"
    )

    mock_analyze_recovery_insights.return_value = (
        "Human connection may be worth continuing to prioritize."
    )

    response = client.post(
        "/recovery-insights/ai-reflection",
        headers=auth_headers(),
    )

    assert response.status_code == 200

    assert response.json() == {
        "reflection": (
            "Human connection may be worth continuing to prioritize."
        ),
    }

    mock_build_recovery_insights.assert_called_once_with()

    mock_analyze_recovery_insights.assert_called_once_with(
        "DETERMINISTIC RECOVERY INSIGHTS"
    )


def test_recovery_insights_ai_requires_authentication():
    response = client.post(
        "/recovery-insights/ai-reflection",
    )

    assert response.status_code == 401


@patch("app.api.analyze_recovery_insights")
@patch("app.api.build_recovery_insights")
def test_recovery_insights_ai_does_not_expose_ai_errors(
    mock_build_recovery_insights,
    mock_analyze_recovery_insights,
):
    mock_build_recovery_insights.return_value = (
        "PRIVATE RECOVERY INSIGHTS"
    )

    mock_analyze_recovery_insights.side_effect = RuntimeError(
        "Provider failed with secret sk-do-not-expose"
    )

    response = client.post(
        "/recovery-insights/ai-reflection",
        headers=auth_headers(),
    )

    assert response.status_code == 502

    assert response.json() == {
        "detail": (
            "Unable to generate Recovery Insights reflection."
        ),
    }

    assert "sk-do-not-expose" not in response.text



@patch("app.api.analyze_recovery_insights")
@patch("app.api.build_recovery_insights")
def test_recovery_insights_ai_accepts_explicit_local_summary(
    mock_build_recovery_insights,
    mock_analyze_recovery_insights,
):
    mock_analyze_recovery_insights.return_value = (
        "Reflection from local summary."
    )

    response = client.post(
        "/recovery-insights/ai-reflection",
        headers=auth_headers(),
        json={
            "summary": "LOCAL RECOVERY INSIGHTS SUMMARY",
        },
    )

    assert response.status_code == 200

    assert response.json() == {
        "reflection": "Reflection from local summary.",
    }

    mock_build_recovery_insights.assert_not_called()

    mock_analyze_recovery_insights.assert_called_once_with(
        "LOCAL RECOVERY INSIGHTS SUMMARY"
    )


@patch("app.api.analyze_recovery_insights")
def test_recovery_insights_ai_rejects_empty_local_summary(
    mock_analyze_recovery_insights,
):
    response = client.post(
        "/recovery-insights/ai-reflection",
        headers=auth_headers(),
        json={
            "summary": "   ",
        },
    )

    assert response.status_code == 400

    mock_analyze_recovery_insights.assert_not_called()
