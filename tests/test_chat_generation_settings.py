from unittest.mock import patch

import pytest

from app.recovery_engine import (
    analyze_checkin_trends,
    analyze_journal_entry,
    analyze_monthly_review,
    analyze_recovery_insights,
    analyze_weekly_review,
    respond_to_user,
)


SPECIALIZED_ANALYZERS = [
    (analyze_journal_entry, "journal input"),
    (analyze_checkin_trends, "check-in input"),
    (analyze_recovery_insights, "insights input"),
    (analyze_weekly_review, "weekly input"),
    (analyze_monthly_review, "monthly input"),
]


def test_ordinary_chat_requests_low_reasoning_effort():
    conversation = [{"role": "user", "content": "I had a hard day."}]

    with patch("app.recovery_engine.generate_response") as mock_generate:
        mock_generate.return_value = "response"

        respond_to_user(conversation)

    kwargs = mock_generate.call_args.kwargs

    assert kwargs["reasoning_effort"] == "low"


def test_ordinary_chat_requests_low_text_verbosity():
    conversation = [{"role": "user", "content": "I had a hard day."}]

    with patch("app.recovery_engine.generate_response") as mock_generate:
        mock_generate.return_value = "response"

        respond_to_user(conversation)

    kwargs = mock_generate.call_args.kwargs

    assert kwargs["verbosity"] == "low"


def test_ordinary_chat_forwards_the_full_conversation_unchanged():
    conversation = [
        {"role": "user", "content": "I had a hard day."},
        {"role": "assistant", "content": "What felt hardest?"},
        {"role": "user", "content": "Staying connected."},
    ]

    with patch("app.recovery_engine.generate_response") as mock_generate:
        mock_generate.return_value = "response"

        respond_to_user(conversation)

    kwargs = mock_generate.call_args.kwargs

    assert kwargs["conversation"] == conversation


@pytest.mark.parametrize("analyzer, supplied_text", SPECIALIZED_ANALYZERS)
def test_specialized_reflections_do_not_inherit_chat_only_settings(
    analyzer,
    supplied_text,
):
    with patch("app.recovery_engine.generate_response") as mock_generate:
        mock_generate.return_value = "reflection"

        analyzer(supplied_text)

    kwargs = mock_generate.call_args.kwargs

    assert "reasoning_effort" not in kwargs
    assert "verbosity" not in kwargs
