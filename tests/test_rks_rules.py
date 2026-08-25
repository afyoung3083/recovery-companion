from tests.rks_rules import (
    contains_no_intermediate_future_step_numbers,
    has_exactly_one_numbered_action,
    has_no_more_than_three_numbered_actions,
    human_connection_is_first_action,
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
