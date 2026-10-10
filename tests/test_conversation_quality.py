"""Offline contracts and harness tests, NOT scores of live model behavior."""
import copy
import json
from pathlib import Path
from types import SimpleNamespace

import pytest

from evals import conversation_comparison as cq

ROOT = Path(__file__).resolve().parent.parent
CASES = cq.load_cases(ROOT)


@pytest.fixture(autouse=True)
def forbid_network(monkeypatch):
    import socket

    def blocked(*args, **kwargs):
        raise AssertionError('Network is forbidden in these offline tests.')

    monkeypatch.setattr(socket.socket, 'connect', blocked)
    monkeypatch.setattr(socket.socket, 'connect_ex', blocked)


class FakeGenerator:
    def __init__(self):
        self.calls = []
        self.closed = False

    def __call__(self, prompt, conversation):
        self.calls.append((prompt, copy.deepcopy(conversation)))
        return {'text': f'{prompt}: synthetic response {len(self.calls)}',
                'input_tokens': 3, 'output_tokens': 4}

    def close(self):
        self.closed = True


def test_corpus_is_multiturn_and_covers_usefulness_and_boundaries():
    assert len(CASES) == 14
    assert len({c['id'] for c in CASES}) == len(CASES)
    tags = {tag for case in CASES for tag in case['tags']}
    assert {'education', 'listening', 'continuity', 'safety', 'privacy',
            'step-progression', 'dependency', 'source-honesty',
            'spiritual-preference', 'medical-boundary'} <= tags
    assert CASES[0]['user_turns'][0] == 'I need to understand a nuance with step 4.'
    assert all(c['review_criteria'] and c['critical_failures'] for c in CASES)


@pytest.mark.parametrize('case', CASES, ids=[c['id'] for c in CASES])
def test_each_case_keeps_generated_history_and_prompt_variants_separate(case):
    original = copy.deepcopy(case)
    generator = FakeGenerator()
    report = cq.compare([case], {'baseline': 'old', 'candidate': 'new'},
                        generator, max_calls=12, model='test-model')
    turns = len(case['user_turns'])
    assert report['requests_attempted'] == 2 * turns
    assert report['status'] == 'complete'
    assert report['quality_verdict'] == 'NOT_EVALUATED'
    assert report['human_review_required'] is True
    for offset, name in ((0, 'old'), (turns, 'new')):
        for index in range(turns):
            prompt, history = generator.calls[offset + index]
            assert prompt == name
            assert [m['role'] for m in history] == ['user', 'assistant'] * index + ['user']
            assert history[-1]['content'] == case['user_turns'][index]
            assert [m['content'] for m in history if m['role'] == 'user'] == case['user_turns'][:index + 1]
            assert all(m['content'].startswith(name) for m in history if m['role'] == 'assistant')
    assert case == original


def test_dry_run_never_constructs_client_reads_prompts_or_overwrites_output(monkeypatch, capsys, tmp_path):
    def forbidden(*args, **kwargs):
        raise AssertionError('Paid setup must not run.')

    monkeypatch.setattr(cq, 'read_prompts', forbidden)
    monkeypatch.setattr(cq, 'configured_model', forbidden)
    monkeypatch.setenv('OPENAI_API_KEY', 'fake-key-that-must-not-be-used')
    path = tmp_path / 'existing.json'
    path.write_text('preserve', encoding='utf-8')
    assert cq.main(['--output', str(path)], root=ROOT, generator_factory=forbidden) == 0
    plan = json.loads(capsys.readouterr().out)
    assert plan['api_calls'] == 0
    assert plan['mode'] == 'OFFLINE_PLAN_ONLY'
    assert plan['planned_requests_if_authorized'] == 6
    assert path.read_text('utf-8') == 'preserve'


@pytest.mark.parametrize('args', [
    ['--live'], ['--allow-paid'], ['--max-calls', '0'], ['--max-calls', '13'],
    ['--cases', 'UNKNOWN'], ['--cases', 'CQ-001,CQ-001'],
    ['--cases', 'CQ-001,CQ-002', '--max-calls', '6'],
    ['--live', '--allow-paid'],
])
def test_invalid_or_unapproved_runs_stop_before_client_creation(args):
    def forbidden(*unused):
        raise AssertionError('No generator should be created.')

    with pytest.raises(SystemExit) as error:
        cq.main(args, root=ROOT, generator_factory=forbidden)
    assert error.value.code == 2


def test_budget_is_checked_before_generating_any_response():
    generator = FakeGenerator()
    with pytest.raises(ValueError):
        cq.compare(CASES[:2], {'baseline': 'old', 'candidate': 'new'},
                   generator, max_calls=6, model='test-model')
    assert generator.calls == []


def test_failure_keeps_partial_evidence_stops_and_never_prints_raw_error():
    calls = []

    def fail_second(prompt, conversation):
        calls.append(copy.deepcopy(conversation))
        if len(calls) == 2:
            raise RuntimeError('FAKE_CREDENTIAL_SHOULD_NOT_APPEAR')
        return {'text': 'First synthetic response'}

    with pytest.raises(cq.ComparisonFailure) as error:
        cq.compare(CASES[:1], {'baseline': 'old', 'candidate': 'new'},
                   fail_second, max_calls=6, model='test-model')
    report = error.value.report
    assert report['status'] == 'incomplete'
    assert report['quality_verdict'] == 'NOT_EVALUATED'
    assert report['requests_attempted'] == len(calls) == 2
    assert 'FAKE_CREDENTIAL' not in json.dumps(report)
    assert 'candidate' not in report['results'][0]['variants']


def test_empty_response_is_not_reported_as_success():
    with pytest.raises(cq.ComparisonFailure) as error:
        cq.compare(CASES[:1], {'baseline': 'old', 'candidate': 'new'},
                   lambda *args: {'text': ' '}, max_calls=6, model='test-model')
    assert error.value.report['requests_attempted'] == 1
    assert error.value.report['status'] == 'incomplete'


def test_authorized_path_with_fake_generator_writes_report_and_closes(monkeypatch, tmp_path):
    generator = FakeGenerator()
    monkeypatch.setattr(cq, 'read_prompts', lambda root: {'baseline': 'old', 'candidate': 'new'})
    monkeypatch.setattr(cq, 'configured_model', lambda root: 'test-model')
    path = tmp_path / 'report.json'
    result = cq.main(['--live', '--allow-paid', '--output', str(path)],
                     root=ROOT, generator_factory=lambda model: generator)
    assert result == 0
    assert generator.closed
    report = json.loads(path.read_text('utf-8'))
    assert report['requests_attempted'] == 6
    assert report['quality_verdict'] == 'NOT_EVALUATED'
    assert report['prompt_sha256']['baseline'] != report['prompt_sha256']['candidate']


def test_existing_report_is_not_overwritten_or_charged(monkeypatch, tmp_path):
    monkeypatch.setattr(cq, 'read_prompts', lambda root: {'baseline': 'old', 'candidate': 'new'})
    monkeypatch.setattr(cq, 'configured_model', lambda root: 'test-model')
    generator = FakeGenerator()
    path = tmp_path / 'existing.json'
    path.write_text('preserve', encoding='utf-8')
    assert cq.main(['--live', '--allow-paid', '--output', str(path)],
                   root=ROOT, generator_factory=lambda model: generator) == 1
    assert path.read_text('utf-8') == 'preserve'
    assert generator.calls == []


def test_configured_model_is_read_without_executing_configuration(tmp_path):
    (tmp_path / 'app').mkdir()
    (tmp_path / 'app/config.py').write_text(
        'raise RuntimeError("must not execute")\nMODEL_NAME = "test-model"\n', encoding='utf-8')
    assert cq.configured_model(tmp_path) == 'test-model'


def test_prompt_preserves_usefulness_safety_and_privacy_contracts():
    prompt = ' '.join((ROOT / 'prompts/system_prompt.md').read_text('utf-8').split())
    for required in (
        'Answer a clear question directly and early.',
        'There is no mandatory confirmation gate.',
        'General education about any Step is allowed',
        'Respect an explicit request to listen without advice.',
        'Do not promise memory across app restarts.',
        'Never invent quotations, page numbers, editions, sources',
        'Significant progression belongs with the user and their sponsor',
        'Do not delay urgent help while seeking reflective confirmation.',
        'Do not diagnose, prescribe, change medication doses',
    ):
        assert required in prompt
    assert '## Reflective Confirmation Gate' not in prompt
    assert 'After asking the confirmation question, END THE RESPONSE.' not in prompt


def test_automatic_workflow_has_no_secret_and_live_job_requires_opt_in():
    workflow = (ROOT / '.github/workflows/rks-evals.yml').read_text('utf-8')
    offline, live = workflow.split('  live-evals:\n', 1)
    assert 'default: false' in offline.split('allow_paid_evaluations:', 1)[1].split('      suite:', 1)[0]
    assert 'secrets.OPENAI_API_KEY' not in offline
    assert "OPENAI_API_KEY: ''" in offline
    assert "if: github.event_name == 'workflow_dispatch' && inputs.allow_paid_evaluations == true" in live
    assert '--live --allow-paid --cases "$CASE_IDS" --max-calls "$MAX_CALLS"' in live
    assert 'pull_request_target' not in workflow
    assert 'workflow_run:' not in workflow
    assert 'contents: read' in workflow


def test_live_adapter_uses_bounded_settings_with_an_sdk_stub(monkeypatch):
    import sys
    created = {}
    requests = []
    response = SimpleNamespace(status='completed', output_text='Synthetic answer',
                               usage=SimpleNamespace(input_tokens=10, output_tokens=20))

    def create_response(**kwargs):
        requests.append(kwargs)
        return response

    def fake_openai(**kwargs):
        created.update(kwargs)
        return SimpleNamespace(responses=SimpleNamespace(create=create_response), close=lambda: None)

    monkeypatch.setitem(sys.modules, 'openai', SimpleNamespace(OpenAI=fake_openai))
    monkeypatch.setenv('OPENAI_API_KEY', 'fake-test-key')
    adapter = cq.LiveGenerator('test-model')
    reply = adapter('test prompt', [{'role': 'user', 'content': 'Fictional turn'}])
    adapter.close()
    assert created['max_retries'] == 0
    assert created['timeout'] == 45.0
    assert len(requests) == 1
    assert requests[0]['store'] is False
    assert requests[0]['max_output_tokens'] == 1400
    assert requests[0]['reasoning'] == {'effort': 'low'}
    assert requests[0]['text'] == {'verbosity': 'low'}
    assert reply == {'text': 'Synthetic answer', 'input_tokens': 10, 'output_tokens': 20}


def test_live_adapter_refuses_missing_key_before_constructing_client(monkeypatch):
    import sys
    monkeypatch.delenv('OPENAI_API_KEY', raising=False)

    def forbidden(**kwargs):
        raise AssertionError('No client may be created without a key.')

    monkeypatch.setitem(sys.modules, 'openai', SimpleNamespace(OpenAI=forbidden))
    with pytest.raises(ValueError):
        cq.LiveGenerator('test-model')
