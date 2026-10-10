"""Check production wiring using a fake generation boundary, never a live model."""
from copy import deepcopy
from pathlib import Path

from app import recovery_engine

ROOT = Path(__file__).resolve().parent.parent


def test_normal_chat_passes_complete_history_and_revised_prompt(monkeypatch):
    conversation = [
        {'role': 'user', 'content': 'I need to understand a nuance with step 4.'},
        {'role': 'assistant', 'content': 'Which nuance or passage do you mean?'},
        {'role': 'user', 'content': 'The discussion of resentments.'},
    ]
    original = deepcopy(conversation)
    captured = {}

    def fake_generate(**kwargs):
        captured.update(deepcopy(kwargs))
        return 'Synthetic test output, not a quality evaluation.'

    monkeypatch.setattr(recovery_engine, 'generate_response', fake_generate)
    result = recovery_engine.respond_to_user(conversation)
    assert result == 'Synthetic test output, not a quality evaluation.'
    assert captured['conversation'] == original == conversation
    assert captured['instructions'] == (ROOT / 'prompts/system_prompt.md').read_text('utf-8').strip()
    assert 'There is no mandatory confirmation gate.' in captured['instructions']
    assert captured['reasoning_effort'] == 'low'
    assert captured['verbosity'] == 'low'


def test_journal_reflection_does_not_use_normal_chat_prompt(monkeypatch):
    captured = {}

    def fake_generate(**kwargs):
        captured.update(deepcopy(kwargs))
        return 'Synthetic reflection.'

    monkeypatch.setattr(recovery_engine, 'generate_response', fake_generate)
    recovery_engine.analyze_journal_entry('Fictional fixture: I washed my car.')
    assert 'Observations' in captured['instructions']
    assert 'Optional suggestions' in captured['instructions']
    assert 'There is no mandatory confirmation gate.' not in captured['instructions']
    assert captured['conversation'] == [{'role': 'user', 'content': 'Fictional fixture: I washed my car.'}]
