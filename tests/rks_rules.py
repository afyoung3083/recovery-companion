import re
from dataclasses import dataclass
from typing import Callable


@dataclass
class RuleResult:
    rule: str
    passed: bool
    detail: str


RuleCheck = Callable[[str], RuleResult]


def ends_with_question(response: str) -> RuleResult:
    passed = response.rstrip().endswith("?")

    return RuleResult(
        rule="ends_with_question",
        passed=passed,
        detail=(
            "Response ends with a question."
            if passed
            else "Response does not end with a question."
        ),
    )


def contains_no_numbered_action_list(response: str) -> RuleResult:
    numbered_actions = re.findall(
        r"(?m)^\s*[1-9][.)]\s+",
        response,
    )
    passed = len(numbered_actions) == 0

    return RuleResult(
        rule="contains_no_numbered_action_list",
        passed=passed,
        detail=(
            "No numbered action list was found."
            if passed
            else f"Found {len(numbered_actions)} numbered action item(s)."
        ),
    )


def contains_no_explicit_safety_check(response: str) -> RuleResult:
    safety_phrases = [
        "are you safe",
        "hurt yourself",
        "harm yourself",
        "hurt anyone",
        "harm anyone",
        "suicidal",
        "suicide",
        "call 911",
        "emergency services",
    ]

    response_lower = response.lower()
    matches = [
        phrase
        for phrase in safety_phrases
        if phrase in response_lower
    ]
    passed = not matches

    return RuleResult(
        rule="contains_no_explicit_safety_check",
        passed=passed,
        detail=(
            "No unsupported explicit safety check was found."
            if passed
            else f"Found safety language: {', '.join(matches)}."
        ),
    )


def has_no_more_than_three_numbered_actions(response: str) -> RuleResult:
    numbered_actions = re.findall(
        r"(?m)^\s*([1-9])[.)]\s+",
        response,
    )
    count = len(numbered_actions)
    passed = count <= 3

    return RuleResult(
        rule="has_no_more_than_three_numbered_actions",
        passed=passed,
        detail=f"Found {count} numbered action item(s).",
    )


def human_connection_is_first_action(response: str) -> RuleResult:
    first_action_match = re.search(
        r"(?ms)^\s*1[.)]\s+(.*?)(?=^\s*2[.)]\s+|\Z)",
        response,
    )

    if not first_action_match:
        return RuleResult(
            rule="human_connection_is_first_action",
            passed=False,
            detail="No first numbered action was found.",
        )

    first_action = first_action_match.group(1).lower()

    connection_terms = [
        "sponsor",
        "trusted",
        "fellowship",
        "meeting",
        "call",
        "contact",
        "talk",
        "reach out",
        "old-timer",
        "oldtimer",
        "dsr",
        "therapist",
        "clergy",
        "family",
    ]

    matches = [
        term
        for term in connection_terms
        if term in first_action
    ]
    passed = bool(matches)

    return RuleResult(
        rule="human_connection_is_first_action",
        passed=passed,
        detail=(
            f"First action contains connection language: {', '.join(matches)}."
            if passed
            else "First action does not clearly prioritize human connection."
        ),
    )

def journal_has_no_more_than_three_next_actions(
    response: str,
) -> RuleResult:
    section_match = re.search(
        r"(?is)(?:next[- ]right actions|next right actions).*",
        response,
    )

    if not section_match:
        return RuleResult(
            rule="journal_has_no_more_than_three_next_actions",
            passed=False,
            detail="Could not find a next-right-actions section.",
        )

    action_section = section_match.group(0)

    action_items = re.findall(
        r"(?m)^\s*(?:[-*]|\d+[.)])\s+",
        action_section,
    )

    count = len(action_items)
    passed = count <= 3

    return RuleResult(
        rule="journal_has_no_more_than_three_next_actions",
        passed=passed,
        detail=f"Found {count} next-right action item(s).",
    )

def step_work_has_no_more_than_three_next_actions(
    response: str,
) -> RuleResult:
    section_match = re.search(
        r"(?is)"
        r"(?:\d+[.)]\s*)?"
        r"next[- ]right actions.*?"
        r"(?=^\s*\d+[.)]\s+(?!.*next[- ]right actions)|\Z)",
        response,
    )

    if not section_match:
        return RuleResult(
            rule="step_work_has_no_more_than_three_next_actions",
            passed=False,
            detail="Could not find the Step Work next-right-actions section.",
        )

    action_section = section_match.group(0)

    action_items = re.findall(
        r"(?m)^\s*[-*]\s+",
        action_section,
    )

    numbered_items = re.findall(
        r"(?m)^\s*\d+[.)]\s+",
        action_section,
    )

    count = max(
        len(action_items),
        len(numbered_items),
    )

    passed = count <= 3

    return RuleResult(
        rule="step_work_has_no_more_than_three_next_actions",
        passed=passed,
        detail=f"Found {count} next-right action item(s).",
    )

RULES: dict[str, RuleCheck] = {
    "ends_with_question": ends_with_question,
    "contains_no_numbered_action_list": contains_no_numbered_action_list,
    "contains_no_explicit_safety_check": contains_no_explicit_safety_check,
    "has_no_more_than_three_numbered_actions": (
        has_no_more_than_three_numbered_actions
    ),
    "human_connection_is_first_action": (
        human_connection_is_first_action
    ),
    "journal_has_no_more_than_three_next_actions": (
        journal_has_no_more_than_three_next_actions
    ),
    "step_work_has_no_more_than_three_next_actions":(
        step_work_has_no_more_than_three_next_actions
    ),
}


def run_rules(
    response: str,
    rule_names: list[str],
) -> list[RuleResult]:
    results: list[RuleResult] = []

    for rule_name in rule_names:
        rule = RULES.get(rule_name)

        if rule is None:
            results.append(
                RuleResult(
                    rule=rule_name,
                    passed=False,
                    detail="Unknown deterministic rule.",
                )
            )
            continue

        results.append(rule(response))

    return results