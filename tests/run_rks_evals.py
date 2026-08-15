import json
import sys
from pathlib import Path
from typing import Any

from app.recovery_engine import (
    analyze_checkin_trends,
    analyze_journal_entry,
    analyze_monthly_review,
    analyze_step_work,
    analyze_weekly_comparison,
    analyze_weekly_review,
    respond_to_user,
)
from tests.rks_grader import grade_response
from tests.rks_rules import run_rules


# ============================================================
# Configuration
# ============================================================

# Keep the RKS cases beside this runner so the suite works
# regardless of the directory from which it is launched.
TEST_FILE = Path(__file__).parent / "rks_cases.json"


# ============================================================
# Test-case loading
# ============================================================

def load_test_cases() -> list[dict[str, Any]]:
    """Load all Recovery Knowledge Standard evaluation cases."""

    with TEST_FILE.open(
        "r",
        encoding="utf-8",
    ) as file:
        test_cases = json.load(file)

    if not isinstance(test_cases, list):
        raise ValueError(
            "RKS test file must contain a JSON list of test cases."
        )

    return test_cases


# ============================================================
# Recovery-engine routing
# ============================================================

def generate_candidate_response(
    test_case: dict[str, Any],
) -> str:
    """
    Route an RKS case to the correct Recovery Companion behavior.

    Most specialized analysis modes operate on the final user message
    in the supplied conversation. Normal chat receives the complete
    conversation history.
    """

    mode = test_case.get("mode", "chat")
    conversation = test_case["conversation"]

    # Specialized analysis cases use the content of the most recent
    # user message as the material being analyzed.
    latest_content = conversation[-1]["content"]

    if mode == "chat":
        return respond_to_user(conversation)

    if mode == "journal_analysis":
        return analyze_journal_entry(latest_content)

    if mode == "step_work_analysis":
        return analyze_step_work(latest_content)

    if mode == "checkin_analysis":
        return analyze_checkin_trends(latest_content)

    if mode == "weekly_review_analysis":
        return analyze_weekly_review(latest_content)

    if mode == "weekly_comparison_analysis":
        return analyze_weekly_comparison(latest_content)

    if mode == "monthly_review_analysis":
        return analyze_monthly_review(latest_content)

    # An unknown mode is probably a typo or an evaluator configuration
    # mistake. Failing explicitly is safer than silently testing chat.
    raise ValueError(
        f"Unsupported RKS evaluation mode: {mode}"
    )


# ============================================================
# Output helpers
# ============================================================

def print_suite_header(
    test_case_count: int,
) -> None:
    """Print the RKS suite heading."""

    print("=" * 60)
    print("Recovery Companion — RKS Evaluation Suite")
    print("=" * 60)
    print(f"Loaded {test_case_count} test cases.")
    print()


def print_case_header(
    test_case: dict[str, Any],
) -> None:
    """Print the heading for one RKS case."""

    print("-" * 60)
    print(
        f"{test_case['id']}: "
        f"{test_case['name']}"
    )
    print("-" * 60)


# ============================================================
# Evaluation runner
# ============================================================

def main() -> None:
    """
    Run every RKS case.

    Each response is checked in two ways:

    1. Deterministic rules verify mechanically enforceable behavior.
    2. The AI grader evaluates broader recovery-language expectations.

    The process exits with code 1 if either layer fails any case.
    """

    test_cases = load_test_cases()

    print_suite_header(
        len(test_cases)
    )

    results: list[tuple[str, str]] = []
    has_failure = False

    for test_case in test_cases:
        print_case_header(test_case)

        # ----------------------------------------------------
        # Generate the Recovery Companion response
        # ----------------------------------------------------

        response = generate_candidate_response(
            test_case
        )

        # ----------------------------------------------------
        # AI-based behavioral grading
        # ----------------------------------------------------

        grade = grade_response(
            conversation=test_case["conversation"],
            candidate_response=response,
            expected_behavior=test_case[
                "expected_behavior"
            ],
        )

        # ----------------------------------------------------
        # Deterministic rule checks
        # ----------------------------------------------------

        rule_results = run_rules(
            response=response,
            rule_names=test_case.get(
                "deterministic_rules",
                [],
            ),
        )

        deterministic_failure = any(
            not result.passed
            for result in rule_results
        )

        grader_failure = (
            grade.verdict == "FAIL"
        )

        if (
            deterministic_failure
            or grader_failure
        ):
            has_failure = True

        results.append(
            (
                test_case["id"],
                grade.verdict,
            )
        )

        # ----------------------------------------------------
        # Per-case output
        # ----------------------------------------------------

        print()
        print("Recovery Companion:")
        print(response)
        print()

        print("Deterministic rules:")

        if not rule_results:
            print("  None")

        for rule_result in rule_results:
            status = (
                "PASS"
                if rule_result.passed
                else "FAIL"
            )

            print(
                f"  {status}: "
                f"{rule_result.rule} — "
                f"{rule_result.detail}"
            )

        print()
        print(f"Verdict: {grade.verdict}")
        print(f"Reason: {grade.reason}")

        if grade.unmet_expectations:
            print("Unmet expectations:")

            for expectation in grade.unmet_expectations:
                print(
                    f"  - {expectation}"
                )

        print()

    # ========================================================
    # Final summary
    # ========================================================

    print("=" * 60)
    print("Summary")
    print("=" * 60)

    for case_id, verdict in results:
        print(
            f"{case_id}: {verdict}"
        )

    print()

    if has_failure:
        print("RKS evaluation result: FAIL")
        sys.exit(1)

    print("RKS evaluation result: PASS")
    sys.exit(0)


# Run the suite only when this module is invoked directly.
# Typical usage from the repository root:
#
#     python -m tests.run_rks_evals
#
if __name__ == "__main__":
    main()