import json
from pathlib import Path

from app.recovery_engine import respond_to_user
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

    for test_case in test_cases:
        print("-" * 60)
        print(f"{test_case['id']}: {test_case['name']}")
        print("-" * 60)

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
    print("=" * 60)

    for case_id, verdict in results:
        print(f"{case_id}: {verdict}")


if __name__ == "__main__":
    main()