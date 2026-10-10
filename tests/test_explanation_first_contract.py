"""Revision-2 specification checks and offline plans, not live quality scores.

These tests check instructions and harness behavior. They do not demonstrate
that a model follows the instructions; actual replies still need human review.
"""
import json
from pathlib import Path
import socket

import pytest

from evals import conversation_comparison as cq

ROOT = Path(__file__).resolve().parent.parent
FOCUS_IDS = ('CQ-015', 'CQ-016', 'CQ-017', 'CQ-018')


@pytest.fixture(autouse=True)
def forbid_network(monkeypatch):
    def blocked(*args, **kwargs):
        raise AssertionError('Explanation-revision tests must stay offline.')

    monkeypatch.setattr(socket.socket, 'connect', blocked)
    monkeypatch.setattr(socket.socket, 'connect_ex', blocked)


def prompt_section(heading, next_heading):
    prompt = (ROOT / 'prompts/system_prompt.md').read_text('utf-8')
    section = prompt.split(heading, 1)[1].split(next_heading, 1)[0]
    return ' '.join(section.split())


def test_education_explains_before_assigning_without_a_rigid_template():
    education = prompt_section('### Understanding and education', '### Reflection and listening')
    assert 'Explain the meaning or distinction first' in education
    assert 'add one brief example when it helps' in education
    assert 'Use natural prose rather than a required sequence' in education
    assert 'these are preferences, not a rigid word limit' in education
    assert 'A question about a recovery idea is not a request for homework' in education
    assert 'describe what it means without instructing this user to perform it' in education


def test_clarification_and_examples_are_not_questionnaires_or_inferences():
    education = prompt_section('### Understanding and education', '### Reflection and listening')
    assert 'ask one short question about the missing detail' in education
    assert 'not a menu of every possible subtopic' in education
    assert 'answer it without another gate' in education
    assert "An illustrative example is fictional, not an inference about this user's motives" in education
    # No hardcoded Step 4 reply to the one observed scenario.
    assert 'Bill Wilson' not in education
    assert 'Step 4' not in education


def test_explanation_rule_preserves_changed_intent_and_urgent_help():
    education = prompt_section('### Understanding and education', '### Reflection and listening')
    assert 'Give procedural help when requested' in education
    assert 'follow that changed request rather than remaining stuck in explanation-only mode' in education
    assert 'Immediate danger still takes priority over an educational framing' in education
    # Existing tests separately check medication, privacy, and human support.


def test_factual_rule_does_not_convert_recovery_teachings_to_risk_rankings():
    honesty = prompt_section('## Factual and interpretive honesty', '## Human relationships and Step progression')
    assert 'Present spiritual teachings as perspectives, not established clinical facts' in honesty
    assert 'unsupported rankings of relapse triggers' in honesty
    assert 'Treat an unsupported ranking as unverified even when the user introduces it' in honesty
    assert 'offer the useful qualified explanation without pretending to have evidence' in honesty


def test_corpus_retains_original_ids_and_adds_four_distinct_transfer_scenarios():
    cases = cq.load_cases(ROOT)
    assert [c['id'] for c in cases[:14]] == [f'CQ-{n:03d}' for n in range(1, 15)]
    assert tuple(c['id'] for c in cases[14:]) == FOCUS_IDS
    assert sum(len(c['user_turns']) for c in cases) == 38
    focused = cases[14:]
    assert all(len(c['user_turns']) == 2 for c in focused)
    assert all('explanation-first' in c['tags'] for c in focused)
    assert len({tuple(c['user_turns']) for c in focused}) == 4
    assert {'boundaries', 'clarification', 'risk-claims', 'intent-switch'} <= {
        tag for case in focused for tag in case['tags']
    }
    assert all('Bill Wilson' not in turn for c in focused for turn in c['user_turns'])


@pytest.mark.parametrize('case_id', FOCUS_IDS)
def test_new_case_plan_is_selectable_and_costs_no_model_calls(case_id, monkeypatch, capsys):
    def forbidden(*args, **kwargs):
        raise AssertionError('An offline plan cannot initialize paid execution.')

    monkeypatch.setattr(cq, 'read_prompts', forbidden)
    monkeypatch.setattr(cq, 'configured_model', forbidden)
    assert cq.main(['--cases', case_id, '--max-calls', '4'],
                   root=ROOT, generator_factory=forbidden) == 0
    plan = json.loads(capsys.readouterr().out)
    assert plan['api_calls'] == 0
    assert plan['selected_cases'] == [case_id]
    assert plan['planned_requests_if_authorized'] == 4
    assert plan['quality_verdict'] == 'NOT_EVALUATED'


def test_step4_plus_distinct_concept_needs_ten_calls_and_cannot_bypass_smaller_cap():
    cases = cq.select_cases(cq.load_cases(ROOT), 'CQ-001,CQ-015')
    assert cq.required_calls(cases, 10) == 10
    with pytest.raises(ValueError):
        cq.required_calls(cases, 6)
    assert cq.MAX_CALLS == 12
    assert cq.MAX_OUTPUT_TOKENS == 1400
