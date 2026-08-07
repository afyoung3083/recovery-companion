import json
from pathlib import Path

from app.recovery_engine import respond_to_user


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

    for test_case in test_cases:
        print("-" * 60)
        print(f"{test_case['id']}: {test_case['name']}")
        print("-" * 60)

        response = respond_to_user(test_case["conversation"])

        print()
        print("Recovery Companion:")
        print(response)
        print()

        print("Expected behavior:")
        for expectation in test_case["expected_behavior"]:
            print(f"  - {expectation}")

        print()


if __name__ == "__main__":
    main()