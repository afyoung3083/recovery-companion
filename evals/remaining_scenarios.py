"""Offline-only coverage plan for remaining recovery and safety scenarios.

This module imports no API client, reads no credentials, and makes no calls.
A passing plan or synthetic-generator test does not certify model behavior.
"""
from __future__ import annotations

import json
from pathlib import Path

from evals.conversation_comparison import MAX_CALLS, load_cases, required_calls, select_cases

ROOT = Path(__file__).resolve().parent.parent
PREVIOUSLY_SAMPLED = frozenset({"CQ-001", "CQ-015"})

# Each two-prompt conversation batch fits the existing 12-call ceiling.
# Put higher-consequence safety/boundary cases first.
BATCHES: tuple[tuple[str, tuple[str, ...], str], ...] = (
    ("urgent-medical", ("CQ-010", "CQ-014"), "urgent safety and medication"),
    ("dependency-steps", ("CQ-008", "CQ-009"), "AI dependence and Step advancement"),
    ("grief-reflection", ("CQ-003", "CQ-004", "CQ-005"), "grief and emotional support"),
    ("continuity-cravings", ("CQ-006", "CQ-013"), "corrections and between-meeting urges"),
    ("sources-privacy-risk", ("CQ-007", "CQ-011", "CQ-017"), "source honesty and private data"),
    ("education-preference", ("CQ-002", "CQ-012", "CQ-016"), "concepts and preferences"),
    ("intent-switch", ("CQ-018",), "switch to practical help"),
)


def build_plan(root: Path = ROOT) -> dict:
    cases = load_cases(root)
    case_ids = {case["id"] for case in cases}
    if len(cases) != 18 or not PREVIOUSLY_SAMPLED <= case_ids:
        raise ValueError("Scenario corpus changed: review the remaining-case plan.")

    listed = [case_id for _, ids, _ in BATCHES for case_id in ids]
    if len(listed) != len(set(listed)):
        raise ValueError("Repeated scenario ID would cause duplicated model calls.")
    if set(listed) != case_ids - PREVIOUSLY_SAMPLED:
        raise ValueError("Plan omits or introduces a scenario ID.")
    if BATCHES[0][0] != "urgent-medical":
        raise ValueError("Urgent safety cases must be reviewed first.")

    batches = []
    for name, ids, focus in BATCHES:
        selected = select_cases(cases, ",".join(ids))
        count = required_calls(selected, MAX_CALLS)
        batches.append({
            "name": name,
            "focus": focus,
            "case_ids": list(ids),
            "user_turns": sum(len(c["user_turns"]) for c in selected),
            "possible_requests": count,
            "max_calls": MAX_CALLS,
            "run_status": "NOT_LIVE_TESTED",
            "human_review_required": True,
        })

    return {
        "mode": "OFFLINE_PLAN_ONLY",
        "api_calls_executed": 0,
        "previously_sampled": sorted(PREVIOUSLY_SAMPLED),
        "remaining_scenarios": len(listed),
        "total_potential_requests": sum(b["possible_requests"] for b in batches),
        "quality_verdict": "NOT_EVALUATED",
        "batches": batches,
    }


def main() -> int:
    print(json.dumps(build_plan(), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
