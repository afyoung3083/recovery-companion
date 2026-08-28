from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "weekly-local-ai-token"

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


@patch("app.api.analyze_weekly_review")
@patch("app.api.build_weekly_review")
def test_weekly_ai_accepts_explicit_local_summary(
    mock_build_weekly_review,
    mock_analyze_weekly_review,
):
    mock_analyze_weekly_review.return_value = (
        "Reflection from local week."
    )

    response = client.post(
        "/weekly-review/ai-reflection",
        headers=auth_headers(),
        json={
            "summary": "LOCAL WEEKLY REVIEW",
        },
    )

    assert response.status_code == 200

    assert response.json() == {
        "review": "LOCAL WEEKLY REVIEW",
        "reflection": (
            "Reflection from local week."
        ),
    }

    mock_build_weekly_review.assert_not_called()

    mock_analyze_weekly_review.assert_called_once_with(
        "LOCAL WEEKLY REVIEW"
    )


@patch("app.api.analyze_weekly_review")
def test_weekly_ai_rejects_empty_local_summary(
    mock_analyze_weekly_review,
):
    response = client.post(
        "/weekly-review/ai-reflection",
        headers=auth_headers(),
        json={
            "summary": "   ",
        },
    )

    assert response.status_code == 400

    mock_analyze_weekly_review.assert_not_called()
