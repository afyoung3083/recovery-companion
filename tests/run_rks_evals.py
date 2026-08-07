import json
import sys
from pathlib import Path

from app.recovery_engine import (
    analyze_journal_entry,
    analyze_step_work,
    respond_to_user,
)
from tests.rks_grader import grade_response
from tests.rks_rules import run_rules


TEST_FILE = Path(__file__).parent / "rks_cases.json"


def load_test_cases() -> list[dict]:
    with TEST_FILE.open("r", encoding="utf-8") as file:
        return json.load(file)


def main() -> None:
    test_cases = load_test_cases()

    print("=" * 60)
    print("Recovery Companion — RKS Evaluation Suite")
    print("=" * 60)
    print(f"Loaded {len(test_cases)} test cases.")
    print()

    results: list[tuple[str, str]] = []
    has_failure = False

    for test_case in test_cases:
        print("-" * 60)
        print(f"{test_case['id']}: {test_case['name']}")
        print("-" * 60)

        mode = test_case.get("mode", "chat")

        if mode == "journal_analysis":
            entry_text = test_case["conversation"][-1]["content"]
            response = analyze_journal_entry(entry_text)

        elif mode == "step_work_analysis":
            step_work_text = test_case["conversation"][-1]["content"]
            response = analyze_step_work(step_work_text)

        else:
            response = respond_to_user(test_case["conversation"])

        grade = grade_response(
            conversation=test_case["conversation"],
            candidate_response=response,
            expected_behavior=test_case["expected_behavior"],
        )

        rule_results = run_rules(
            response=response,
            rule_names=test_case.get("deterministic_rules", []),
        )

        if any(not result.passed for result in rule_results):
            has_failure = True

        if grade.verdict == "FAIL":
            has_failure = True

        results.append((test_case["id"], grade.verdict))

        print()
        print("Recovery Companion:")
        print(response)
        print()
        print("Deterministic rules:")

        for rule_result in rule_results:
            status = "PASS" if rule_result.passed else "FAIL"
            print(
                f"  {status}: {rule_result.rule} — "
                f"{rule_result.detail}"
            )

        print()
        print(f"Verdict: {grade.verdict}")
        print(f"Reason: {grade.reason}")

        if grade.unmet_expectations:
            print("Unmet expectations:")
            for expectation in grade.unmet_expectations:
                print(f"  - {expectation}")

        print()

    print("=" * 60)
    print("Summary")
    if has_failure:
        print()
        print("RKS evaluation result: FAIL")
        sys.exit(1)

    print()
    print("RKS evaluation result: PASS")
    sys.exit(0)
    print("=" * 60)

    for case_id, verdict in results:
        print(f"{case_id}: {verdict}")


if __name__ == "__main__":
    main()