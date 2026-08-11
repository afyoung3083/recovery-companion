from app.step_work import format_step_work


def test_format_step_work_shows_current_step():
    step_work = {
        "current_step": 1,
        "assignments": [],
        "notes": [],
    }

    output = format_step_work(step_work)

    assert "Current Step: 1" in output


def test_format_step_work_shows_open_assignment():
    step_work = {
        "current_step": 1,
        "assignments": [
            {
                "id": 1,
                "step": 1,
                "text": "Write about unmanageability.",
                "completed": False,
            }
        ],
        "notes": [],
    }

    output = format_step_work(step_work)

    assert "[ ] 1: Write about unmanageability." in output


def test_format_step_work_shows_completed_assignment():
    step_work = {
        "current_step": 1,
        "assignments": [
            {
                "id": 1,
                "step": 1,
                "text": "Write about unmanageability.",
                "completed": True,
            }
        ],
        "notes": [],
    }

    output = format_step_work(step_work)

    assert "[✓] 1: Write about unmanageability." in output


def test_format_step_work_only_shows_current_step_items():
    step_work = {
        "current_step": 2,
        "assignments": [
            {
                "id": 1,
                "step": 1,
                "text": "Step One assignment.",
                "completed": False,
            },
            {
                "id": 2,
                "step": 2,
                "text": "Step Two assignment.",
                "completed": False,
            },
        ],
        "notes": [
            {
                "id": 1,
                "step": 1,
                "text": "Old Step One note.",
            },
            {
                "id": 2,
                "step": 2,
                "text": "Current Step Two note.",
            },
        ],
    }

    output = format_step_work(step_work)

    assert "Step Two assignment." in output
    assert "Current Step Two note." in output
    assert "Step One assignment." not in output
    assert "Old Step One note." not in output
    