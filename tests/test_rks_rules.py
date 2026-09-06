from tests.rks_rules import (
    contains_no_intermediate_future_step_numbers,
    has_exactly_one_numbered_action,
    has_no_more_than_three_numbered_actions,
    human_connection_is_first_action,
    missed_actions_are_not_moralized,
    neutral_event_avoids_unsupported_inference,
    specialized_reflection_has_two_sections,
    specialized_suggestions_are_optional,
)


def test_ranked_rules_ignore_numbered_material_outside_actions():
    response = """
Two observations:

1. Recovery has felt flat lately.
2. You are still consistently showing up.

Next-right actions

1. Call your sponsor or another trusted recovery person and talk
   honestly about the spiritual flatness.
2. Set aside a short period for prayer without trying to force
   a particular feeling.
3. Keep attending your regular meeting and notice what resonates.

Human connection comes first because recovery is not meant to be
worked in isolation.
"""

    count_result = (
        has_no_more_than_three_numbered_actions(
            response
        )
    )

    connection_result = (
        human_connection_is_first_action(
            response
        )
    )

    assert count_result.passed is True
    assert connection_result.passed is True


def test_ranked_rule_rejects_more_than_three_actions():
    response = """
Next-right actions

1. Call your sponsor.
2. Attend a meeting.
3. Pray.
4. Journal.
"""

    result = (
        has_no_more_than_three_numbered_actions(
            response
        )
    )

    assert result.passed is False


def test_connection_rule_rejects_solitary_first_action():
    response = """
Next-right actions

1. Journal alone about the situation.
2. Call your sponsor.
3. Attend a meeting.
"""

    result = (
        human_connection_is_first_action(
            response
        )
    )

    assert result.passed is False


def test_specialized_reflection_rules_accept_concise_optional_response():
    response = """
Observations

Watering the garden is the activity described. No reason for it is provided.
That detail can remain simply descriptive.

Optional suggestions

- If useful, you might notice what stood out to you while doing it.
"""

    assert specialized_reflection_has_two_sections(response).passed is True
    assert specialized_suggestions_are_optional(response).passed is True
    assert neutral_event_avoids_unsupported_inference(response).passed is True


def test_specialized_reflection_rules_reject_old_sections_and_directives():
    response = """
Observed strengths
- You did well.

Next-right actions
- Call your sponsor.
"""

    assert specialized_reflection_has_two_sections(response).passed is False
    assert specialized_suggestions_are_optional(response).passed is False


def test_specialized_reflection_rules_reject_unsupported_neutral_inference():
    response = """
Observations

Watering the garden may reflect control and restlessness.

Optional suggestions
"""

    assert neutral_event_avoids_unsupported_inference(response).passed is False


def test_neutral_event_rule_rejects_weather_acceptance_inference():
    response = """
Observations

Watering the garden was followed by rain, which may be a lesson in acceptance
and letting go of control.

Optional suggestions

- You could consider practicing acceptance of the weather.
"""

    assert neutral_event_avoids_unsupported_inference(response).passed is False


def test_specialized_reflection_rules_reject_moralized_missed_actions():
    response = """
Observations

Two check-in actions were missed, showing worsening recovery and likely relapse.

Optional suggestions
"""

    assert missed_actions_are_not_moralized(response).passed is False


def test_ranked_rules_require_action_section():
    response = """
1. Call your sponsor.
2. Attend a meeting.
3. Pray.
"""

    assert (
        has_no_more_than_three_numbered_actions(
            response
        ).passed
        is False
    )

    assert (
        human_connection_is_first_action(
            response
        ).passed
        is False
    )


def test_ranked_rules_accept_markdown_action_heading():
    response = """
Observations:

1. Recovery has felt flat.
2. You are still showing up.

### **Next-right actions:**

1. Call your sponsor and talk honestly about what feels flat.
2. Spend a short period in prayer.
3. Continue attending your regular meeting.
"""

    assert (
        has_no_more_than_three_numbered_actions(
            response
        ).passed
        is True
    )

    assert (
        human_connection_is_first_action(
            response
        ).passed
        is True
    )


def test_exactly_one_action_accepts_one_action():
    response = """
Next-right actions

1. Call your sponsor today.

After that conversation, focus on what comes next.
"""

    assert (
        has_exactly_one_numbered_action(
            response
        ).passed
        is True
    )


def test_exactly_one_action_rejects_skipped_numbering():
    response = """
Next-right actions

1. Call your sponsor.
3. Write questions about future amends.
"""

    assert (
        has_exactly_one_numbered_action(
            response
        ).passed
        is False
    )


def test_future_step_rule_rejects_intermediate_roadmap():
    response = """
Don't jump to Step 9.

Next-right actions

1. Call your sponsor.

Then do Steps 6 and 7 and build a Step 8 list.
"""

    assert (
        contains_no_intermediate_future_step_numbers(
            response
        ).passed
        is False
    )


def test_future_step_rule_allows_current_and_named_target():
    response = """
Don't jump from Step 5 to Step 9 on your own.

Next-right actions

1. Call your sponsor and review where you are on Step 5.

After that, focus on what comes next.
"""

    assert (
        contains_no_intermediate_future_step_numbers(
            response
        ).passed
        is True
    )
