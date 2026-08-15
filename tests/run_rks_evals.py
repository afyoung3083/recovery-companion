import argparse
import json
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from time import perf_counter
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
from tests.rks_rules import RuleResult, run_rules


# ============================================================
# Configuration
# ============================================================

# Keep the test-case file beside this runner so the suite works
# regardless of the directory from which it is launched.
TEST_FILE = Path(__file__).parent / "rks_cases.json"

# Size separators to the visible terminal, while keeping output
# reasonable in very wide or unusually narrow terminals.
TERMINAL_WIDTH = max(
    72,
    min(
        shutil.get_terminal_size(
            fallback=(90, 24)
        ).columns,
        100,
    ),
)


# ============================================================
# Result model
# ============================================================

@dataclass
class CaseResult:
    """Summary metrics and diagnostics for one RKS evaluation case."""

    case_id: str
    name: str
    mode: str

    status: str
    grader_verdict: str

    rules_passed: int
    rules_total: int

    generation_seconds: float
    grading_seconds: float
    rules_seconds: float
    total_seconds: float

    response: str = ""
    grade_reason: str = ""
    unmet_expectations: list[str] | None = None
    rule_results: list[RuleResult] | None = None
    error: str | None = None


# ============================================================
# Command-line options
# ============================================================

def parse_args() -> argparse.Namespace:
    """
    Parse command-line options.

    Default:
        Show the compact RKS dashboard only.

    --verbose:
        Also show full model responses, grader explanations,
        and deterministic-rule details.
    """

    parser = argparse.ArgumentParser(
        description=(
            "Run the Recovery Companion "
            "Recovery Knowledge Standard evaluation suite."
        )
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help=(
            "Show full Recovery Companion responses and "
            "detailed grading information."
        ),
    )

    return parser.parse_args()


# ============================================================
# Test-case loading
# ============================================================

def load_test_cases() -> list[dict[str, Any]]:
    """Load and validate all RKS evaluation cases."""

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
    Route one RKS case to the appropriate Recovery Companion feature.

    Normal chat receives the complete conversation.

    Specialized analysis modes use the content of the final supplied
    user message as the material being analyzed.
    """

    mode = test_case.get("mode", "chat")
    conversation = test_case["conversation"]

    if not conversation:
        raise ValueError(
            f"{test_case.get('id', 'Unknown case')} "
            "contains no conversation messages."
        )

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

    # Unknown modes should fail explicitly instead of silently
    # running as ordinary chat.
    raise ValueError(
        f"Unsupported RKS evaluation mode: {mode}"
    )


# ============================================================
# Individual case execution
# ============================================================

def evaluate_case(
    test_case: dict[str, Any],
) -> CaseResult:
    """
    Run one complete RKS evaluation.

    Timing is measured separately for:

    1. Recovery Companion response generation
    2. AI behavioral grading
    3. Deterministic rule evaluation
    """

    case_start = perf_counter()

    case_id = test_case["id"]
    name = test_case["name"]
    mode = test_case.get("mode", "chat")

    try:
        # ----------------------------------------------------
        # Generate candidate response
        # ----------------------------------------------------

        generation_start = perf_counter()

        response = generate_candidate_response(
            test_case
        )

        generation_seconds = (
            perf_counter() - generation_start
        )

        # ----------------------------------------------------
        # AI behavioral grading
        # ----------------------------------------------------

        grading_start = perf_counter()

        grade = grade_response(
            conversation=test_case["conversation"],
            candidate_response=response,
            expected_behavior=test_case[
                "expected_behavior"
            ],
        )

        grading_seconds = (
            perf_counter() - grading_start
        )

        # ----------------------------------------------------
        # Deterministic rule checks
        # ----------------------------------------------------

        rules_start = perf_counter()

        rule_results = run_rules(
            response=response,
            rule_names=test_case.get(
                "deterministic_rules",
                [],
            ),
        )

        rules_seconds = (
            perf_counter() - rules_start
        )

        rules_passed = sum(
            1
            for result in rule_results
            if result.passed
        )

        rules_total = len(rule_results)

        deterministic_passed = (
            rules_passed == rules_total
        )

        grader_passed = (
            grade.verdict == "PASS"
        )

        status = (
            "PASS"
            if deterministic_passed and grader_passed
            else "FAIL"
        )

        return CaseResult(
            case_id=case_id,
            name=name,
            mode=mode,
            status=status,
            grader_verdict=grade.verdict,
            rules_passed=rules_passed,
            rules_total=rules_total,
            generation_seconds=generation_seconds,
            grading_seconds=grading_seconds,
            rules_seconds=rules_seconds,
            total_seconds=(
                perf_counter() - case_start
            ),
            response=response,
            grade_reason=grade.reason,
            unmet_expectations=(
                grade.unmet_expectations
            ),
            rule_results=rule_results,
        )

    except Exception as error:
        # Harness failures, malformed cases, API errors, and similar
        # exceptions are reported as ERROR rather than behavioral FAIL.
        return CaseResult(
            case_id=case_id,
            name=name,
            mode=mode,
            status="ERROR",
            grader_verdict="-",
            rules_passed=0,
            rules_total=0,
            generation_seconds=0.0,
            grading_seconds=0.0,
            rules_seconds=0.0,
            total_seconds=(
                perf_counter() - case_start
            ),
            error=str(error),
        )


# ============================================================
# Dashboard formatting helpers
# ============================================================

def shorten(
    text: str,
    width: int,
) -> str:
    """Shorten text so dashboard rows remain compact."""

    if len(text) <= width:
        return text

    return text[: width - 3] + "..."


def format_seconds(
    seconds: float,
) -> str:
    """Format elapsed time compactly."""

    if seconds < 1:
        return f"{seconds * 1000:.0f}ms"

    return f"{seconds:.2f}s"


def print_separator(
    character: str = "-",
) -> None:
    """Print a separator sized to the current terminal."""

    print(character * TERMINAL_WIDTH)


def print_suite_header(
    test_count: int,
) -> None:
    """Print the compact RKS dashboard heading."""

    print()
    print_separator("=")
    print("Recovery Companion - RKS Evaluation")
    print_separator("=")

    print(
        f"{test_count} cases | "
        "AI grader + deterministic rules"
    )

    print()


def print_case_row(
    result: CaseResult,
) -> None:
    """Print one compact test-result row."""

    rules_display = (
        f"{result.rules_passed}/{result.rules_total}"
        if result.rules_total
        else "-"
    )

    name = shorten(
        result.name,
        30,
    )

    print(
        f"{result.status:<5} "
        f"{result.case_id:<7} "
        f"{name:<30} "
        f"rules {rules_display:<3} "
        f"| gen {format_seconds(result.generation_seconds):>7} "
        f"| grade {format_seconds(result.grading_seconds):>7} "
        f"| total {format_seconds(result.total_seconds):>7}"
    )


# ============================================================
# Failure and verbose details
# ============================================================

def print_failure_details(
    result: CaseResult,
) -> None:
    """Show diagnostics only for failed or errored cases."""

    print()
    print(
        f"{result.status}: "
        f"{result.case_id} - {result.name}"
    )

    if result.error:
        print(
            f"  Error: {result.error}"
        )
        return

    print(
        f"  AI grader: {result.grader_verdict}"
    )

    if result.grade_reason:
        print(
            f"  Reason: {result.grade_reason}"
        )

    if result.unmet_expectations:
        print("  Unmet expectations:")

        for expectation in result.unmet_expectations:
            print(
                f"    - {expectation}"
            )

    failed_rules = [
        rule
        for rule in (result.rule_results or [])
        if not rule.passed
    ]

    if failed_rules:
        print(
            "  Failed deterministic rules:"
        )

        for rule in failed_rules:
            print(
                f"    - {rule.rule}: "
                f"{rule.detail}"
            )


def print_verbose_details(
    result: CaseResult,
) -> None:
    """Show full response and grading details when --verbose is used."""

    print()
    print_separator("=")
    print(
        f"{result.case_id}: {result.name}"
    )
    print_separator("=")

    if result.error:
        print(
            f"ERROR: {result.error}"
        )
        return

    print()
    print(
        "Recovery Companion response:"
    )
    print_separator()
    print(result.response)

    print()
    print(
        "Deterministic rules:"
    )
    print_separator()

    if not result.rule_results:
        print("None")

    for rule in result.rule_results or []:
        status = (
            "PASS"
            if rule.passed
            else "FAIL"
        )

        print(
            f"{status}: "
            f"{rule.rule} - {rule.detail}"
        )

    print()
    print(
        f"AI grader: {result.grader_verdict}"
    )
    print(
        f"Reason: {result.grade_reason}"
    )

    if result.unmet_expectations:
        print(
            "Unmet expectations:"
        )

        for expectation in result.unmet_expectations:
            print(
                f"  - {expectation}"
            )


# ============================================================
# Suite summary
# ============================================================

def print_suite_summary(
    results: list[CaseResult],
    suite_seconds: float,
) -> None:
    """Print aggregate suite metrics."""

    total = len(results)

    passed = sum(
        result.status == "PASS"
        for result in results
    )

    failed = sum(
        result.status == "FAIL"
        for result in results
    )

    errors = sum(
        result.status == "ERROR"
        for result in results
    )

    generation_seconds = sum(
        result.generation_seconds
        for result in results
    )

    grading_seconds = sum(
        result.grading_seconds
        for result in results
    )

    rules_seconds = sum(
        result.rules_seconds
        for result in results
    )

    average_seconds = (
        sum(
            result.total_seconds
            for result in results
        ) / total
        if total
        else 0.0
    )

    pass_rate = (
        passed / total * 100
        if total
        else 0.0
    )

    slowest = (
        max(
            results,
            key=lambda result: result.total_seconds,
        )
        if results
        else None
    )

    overall = (
        "PASS"
        if failed == 0 and errors == 0
        else "FAIL"
    )

    print()
    print_separator("=")
    print("Summary")
    print_separator("=")

    print(
        f"{overall} | "
        f"{passed}/{total} passed | "
        f"{failed} failed | "
        f"{errors} errors | "
        f"{pass_rate:.1f}%"
    )

    print()
    print(
        f"Total:    {format_seconds(suite_seconds)}"
    )
    print(
        f"Generate: {format_seconds(generation_seconds)}"
    )
    print(
        f"Grade:    {format_seconds(grading_seconds)}"
    )
    print(
        f"Rules:    {format_seconds(rules_seconds)}"
    )
    print(
        f"Average:  {format_seconds(average_seconds)} / case"
    )

    if slowest:
        print(
            f"Slowest:  "
            f"{slowest.case_id} "
            f"({format_seconds(slowest.total_seconds)})"
        )

    print_separator("=")
    print()


# ============================================================
# Evaluation runner
# ============================================================

def main() -> None:
    """
    Run the complete RKS suite and display a compact dashboard.

    Exit codes:

        0 = all cases passed
        1 = one or more cases failed or errored

    Use --verbose to display complete model responses and grader
    details for every case.
    """

    args = parse_args()

    suite_start = perf_counter()

    test_cases = load_test_cases()

    print_suite_header(
        len(test_cases)
    )

    results: list[CaseResult] = []

    for test_case in test_cases:
        result = evaluate_case(
            test_case
        )

        results.append(
            result
        )

        print_case_row(
            result
        )

    suite_seconds = (
        perf_counter() - suite_start
    )

    # --------------------------------------------------------
    # Failure diagnostics
    # --------------------------------------------------------

    failures = [
        result
        for result in results
        if result.status != "PASS"
    ]

    if failures:
        print()
        print_separator("=")
        print("Failure Details")
        print_separator("=")

        for result in failures:
            print_failure_details(
                result
            )

    # --------------------------------------------------------
    # Optional full details
    # --------------------------------------------------------

    if args.verbose:
        for result in results:
            print_verbose_details(
                result
            )

    # --------------------------------------------------------
    # Final dashboard summary
    # --------------------------------------------------------

    print_suite_summary(
        results,
        suite_seconds,
    )

    has_failure = any(
        result.status != "PASS"
        for result in results
    )

    sys.exit(
        1 if has_failure else 0
    )


# ============================================================
# Entry point
# ============================================================

# Normal compact dashboard:
#
#     python -m tests.run_rks_evals
#
# Full model responses and grader details:
#
#     python -m tests.run_rks_evals --verbose
#
if __name__ == "__main__":
    main()