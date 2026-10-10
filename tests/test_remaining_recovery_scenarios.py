"""Offline safety/recovery coverage tests, not model-quality judgments."""
from __future__ import annotations

import copy
import json
import socket

import pytest

from evals import conversation_comparison as cq
from evals import remaining_scenarios as rs


@pytest.fixture(autouse=True)
def forbid_network(monkeypatch):
    def blocked(*args, **kwargs):
        raise AssertionError("Remaining-scenario coverage tests must stay offline.")
    monkeypatch.setattr(socket.socket, "connect", blocked)
    monkeypatch.setattr(socket.socket, "connect_ex", blocked)


def test_plan_covers_every_remaining_scenario_once_and_safety_first():
    plan = rs.build_plan()
    assert plan["mode"] == "OFFLINE_PLAN_ONLY"
    assert plan["api_calls_executed"] == 0
    assert plan["quality_verdict"] == "NOT_EVALUATED"
    assert plan["previously_sampled"] == ["CQ-001", "CQ-015"]
    assert plan["remaining_scenarios"] == 16
    assert plan["total_potential_requests"] == 66
    assert len(plan["batches"]) == 7
    assert plan["batches"][0]["case_ids"] == ["CQ-010", "CQ-014"]
    ids = [case_id for batch in plan["batches"] for case_id in batch["case_ids"]]
    assert len(ids) == len(set(ids)) == 16
    assert set(ids) | set(plan["previously_sampled"]) == {
        c["id"] for c in cq.load_cases()
    }
    assert all(batch["possible_requests"] <= cq.MAX_CALLS for batch in plan["batches"])
    assert all(batch["run_status"] == "NOT_LIVE_TESTED" for batch in plan["batches"])


@pytest.mark.parametrize("name,ids,focus", rs.BATCHES, ids=[b[0] for b in rs.BATCHES])
def test_each_batch_exercises_both_histories_without_model_calls(name, ids, focus):
    selected = cq.select_cases(cq.load_cases(), ",".join(ids))
    calls = []

    def fake_generator(prompt, history):
        calls.append((prompt, copy.deepcopy(history)))
        return {"text": "Synthetic response; not a real model evaluation."}

    report = cq.compare(
        selected,
        {"baseline": "frozen baseline", "candidate": "proposed candidate"},
        fake_generator,
        max_calls=cq.MAX_CALLS,
        model="synthetic",
    )
    assert report["status"] == "complete"
    assert report["quality_verdict"] == "NOT_EVALUATED"
    assert report["human_review_required"] is True
    assert report["requests_attempted"] == len(calls) == 2 * sum(
        len(case["user_turns"]) for case in selected
    )
    assert len(report["results"]) == len(selected)
    for item in report["results"]:
        assert set(item["variants"]) == {"baseline", "candidate"}
    for prompt, history in calls:
        assert prompt in {"frozen baseline", "proposed candidate"}
        assert history[-1]["role"] == "user"
        assert all(item["role"] in {"user", "assistant"} for item in history)


def test_full_remaining_suite_cannot_run_under_single_budget():
    selected = cq.select_cases(
        cq.load_cases(),
        ",".join(case_id for _, ids, _ in rs.BATCHES for case_id in ids),
    )
    with pytest.raises(ValueError, match="cap is"):
        cq.required_calls(selected, cq.MAX_CALLS)


def test_duplicate_or_missing_scenario_is_a_hard_error(monkeypatch):
    original = rs.BATCHES
    monkeypatch.setattr(rs, "BATCHES", original[:-1])
    with pytest.raises(ValueError, match="omits"):
        rs.build_plan()
    monkeypatch.setattr(rs, "BATCHES", original + (("duplicate", ("CQ-010",), "invalid"),))
    with pytest.raises(ValueError, match="Repeated"):
        rs.build_plan()


def test_offline_cli_does_not_use_or_disclose_key(monkeypatch, capsys):
    monkeypatch.setenv("OPENAI_API_KEY", "fake-should-not-appear")
    assert rs.main() == 0
    result = json.loads(capsys.readouterr().out)
    assert result["api_calls_executed"] == 0
    assert result["total_potential_requests"] == 66
    assert "fake-should-not-appear" not in json.dumps(result)


def test_prompt_selects_intent_before_response_format_and_retains_safety():
    text = (rs.ROOT / "prompts/system_prompt.md").read_text("utf-8")
    assert text.index("## Respond to the actual request") < text.index("### Understanding and education")
    for phrase in (
        "Immediate danger or a medical emergency",
        "Understanding a concept, passage, or distinction",
        "Sharing feelings or asking to be heard",
        "Explicitly asking what to do",
        "help first, not referral first",
        "For an **explanation-only** request",
        "Do not smuggle an assignment",
        "ask one short question about the missing detail",
        "greatest causal predictor of relapse",
        "Do not diagnose, prescribe, change medication doses",
        "Do not delay urgent help",
        "Do not promise memory across app restarts",
        "Do not frame abuse or victimization as the user's fault",
        "Do not encourage",
    ):
        assert phrase in text


def test_remaining_safety_cases_keep_critical_failures_and_review_criteria():
    cases = {case["id"]: case for case in cq.load_cases()}
    for case_id in (
        "CQ-005", "CQ-008", "CQ-009", "CQ-010",
        "CQ-011", "CQ-013", "CQ-014", "CQ-017",
    ):
        c = cases[case_id]
        assert len(c["critical_failures"]) >= 2
        assert c["review_criteria"]
    assert "immediate" in json.dumps(cases["CQ-010"]).lower()
    assert "medication" in json.dumps(cases["CQ-014"]).lower()
    assert "dependence" in json.dumps(cases["CQ-008"]).lower()
