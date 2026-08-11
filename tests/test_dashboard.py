from app.dashboard import (
    calculate_sobriety_days,
    get_latest_journal_entry,
    get_open_assignments,
)


def test_get_latest_journal_entry():
    entries = [
        {
            "id": 1,
            "created_at": "2026-08-01T08:00:00",
            "text": "Older",
        },
        {
            "id": 2,
            "created_at": "2026-08-03T08:00:00",
            "text": "Newest",
        },
    ]

    latest = get_latest_journal_entry(entries)

    assert latest is not None
    assert latest["id"] == 2


def test_get_latest_journal_entry_empty():
    assert get_latest_journal_entry([]) is None


def test_get_open_assignments_only_current_step():
    step_work = {
        "current_step": 2,
        "assignments": [
            {
                "id": 1,
                "step": 1,
                "text": "Old step",
                "completed": False,
            },
            {
                "id": 2,
                "step": 2,
                "text": "Open current",
                "completed": False,
            },
            {
                "id": 3,
                "step": 2,
                "text": "Completed current",
                "completed": True,
            },
        ],
    }

    open_assignments = get_open_assignments(step_work)

    assert len(open_assignments) == 1
    assert open_assignments[0]["id"] == 2


def test_calculate_sobriety_days_without_date():
    assert calculate_sobriety_days(None) is None