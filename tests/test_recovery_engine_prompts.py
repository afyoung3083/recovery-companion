from unittest.mock import patch

import pytest

from app.recovery_engine import (
    analyze_checkin_trends,
    analyze_journal_entry,
    analyze_monthly_review,
    analyze_recovery_insights,
    analyze_weekly_review,
)


ANALYZERS = [
    (analyze_journal_entry, "journal input"),
    (analyze_checkin_trends, "check-in input"),
    (analyze_recovery_insights, "insights input"),
    (analyze_weekly_review, "weekly input"),
    (analyze_monthly_review, "monthly input"),
]


@pytest.mark.parametrize("analyzer, supplied_text", ANALYZERS)
def test_specialized_reflections_use_the_short_optional_contract(
    analyzer,
    supplied_text,
):
    with patch("app.recovery_engine.generate_response") as mock_generate:
        mock_generate.return_value = "reflection"

        result = analyzer(supplied_text)

    assert result == "reflection"
    mock_generate.assert_called_once()
    instructions = mock_generate.call_args.kwargs["instructions"]

    assert "Observations" in instructions
    assert "Optional suggestions" in instructions
    assert "80 to 150 words" in instructions
    assert "approximately 3 to 4 concise sentences" in instructions
    assert "zero to three short bullets" in instructions
    assert '"If useful, you might..."' in instructions
    assert '"You could consider..."' in instructions
    assert "Do not invent motives, causes, fears" in instructions
    assert "phrase them tentatively" in instructions
    assert "recovery scores" in instructions
    assert "do not replace a sponsor" in instructions


def test_journal_prompt_no_longer_requests_five_analysis_categories():
    with patch("app.recovery_engine.generate_response") as mock_generate:
        mock_generate.return_value = "reflection"

        analyze_journal_entry("Watered the garden.")

    instructions = mock_generate.call_args.kwargs["instructions"]

    assert "Recovery themes" not in instructions
    assert "Possible recurring patterns" not in instructions
    assert "Victories or evidence of progress" not in instructions
    assert "Items worth discussing with a sponsor" not in instructions
    assert "Next-right actions" not in instructions


def test_prompt_contract_requires_neutral_events_to_remain_grounded():
    with patch("app.recovery_engine.generate_response") as mock_generate:
        mock_generate.return_value = "reflection"

        analyze_journal_entry("Watered the garden.")

    instructions = mock_generate.call_args.kwargs["instructions"]

    assert "neutral activities may remain neutral" in instructions
    assert "isolated events or missing context" in instructions
    assert "Do not force an interpretation for every fact" in instructions
    assert "ordinary neutral events or their sequence" in instructions
    assert "Weather, chores, timing" in instructions
    assert "coincidences" in instructions
    assert "Optional suggestions must not introduce" in instructions


def test_prompt_contract_treats_missed_checkins_as_descriptive():
    with patch("app.recovery_engine.generate_response") as mock_generate:
        mock_generate.return_value = "reflection"

        analyze_checkin_trends("Prayer: 1/3\nMeeting: 0/3")

    instructions = mock_generate.call_args.kwargs["instructions"]

    assert "missed actions" in instructions
    assert "prove poor recovery" in instructions
    assert "Suggestions are not assignments" in instructions
