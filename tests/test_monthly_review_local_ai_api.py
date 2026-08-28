from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import app.auth as auth_module
from app.api import app


TEST_API_TOKEN = "monthly-local-ai-token"

client = TestClient(app)


@pytest.fixture(autouse=True)
def configure_test_api_token(monkeypatch):
    monkeypatch.setattr(
        auth_module,
        "RECOVERY_API_TOKEN",
        TEST_API_TOKEN,
    )


def auth_headers() -> dict[str, str]:
    return {
        "Authorization": f"Bearer {TEST_API_TOKEN}",
    }


@patch("app.api.analyze_monthly_review")
@patch("app.api.build_monthly_review")
def test_monthly_ai_accepts_explicit_local_summary(
    mock_build_monthly_review,
    mock_analyze_monthly_review,
):
    mock_analyze_monthly_review.return_value = (
        "Reflection from local month."
    )

    response = client.post(
        "/monthly-review/ai-reflection",
        headers=auth_headers(),
        json={
            "summary": "LOCAL MONTHLY REVIEW",
        },
    )

    assert response.status_code == 200

    assert response.json() == {
        "review": "LOCAL MONTHLY REVIEW",
        "reflection": "Reflection from local month.",
    }

    mock_build_monthly_review.assert_not_called()

    mock_analyze_monthly_review.assert_called_once_with(
        "LOCAL MONTHLY REVIEW"
    )


@patch("app.api.analyze_monthly_review")
def test_monthly_ai_rejects_empty_local_summary(
    mock_analyze_monthly_review,
):
    response = client.post(
        "/monthly-review/ai-reflection",
        headers=auth_headers(),
        json={
            "summary": "   ",
        },
    )

    assert response.status_code == 400

    mock_analyze_monthly_review.assert_not_called()
