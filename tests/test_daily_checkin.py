from app.daily_checkin import (
    CHECKIN_FIELDS,
    count_completed_actions,
    summarize_checkin_trends,
)


def test_count_completed_actions():
    checkin = {
        "prayer_meditation": True,
        "recovery_contact": True,
        "meeting": False,
        "step_work": True,
        "journal": False,
        "service": True,
    }

    assert count_completed_actions(checkin) == 4


def test_summarize_checkin_trends():
    checkins = [
        {field: True for field in CHECKIN_FIELDS},
        {field: False for field in CHECKIN_FIELDS},
    ]

    summary = summarize_checkin_trends(checkins)

    assert summary["days"] == 2

    for field in CHECKIN_FIELDS:
        assert summary["totals"][field] == 1