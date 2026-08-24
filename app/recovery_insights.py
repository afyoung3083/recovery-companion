from typing import Any

from app.daily_checkin import get_recent_checkins
from app.dashboard import calculate_sobriety_days
from app.goals import get_active_goals
from app.monthly_review import load_monthly_review_history
from app.profile import load_profile
from app.step_work import load_step_work
from app.weekly_review import load_weekly_review_history


# ============================================================
# Snapshot helpers
# ============================================================

def _latest_snapshot(
    history: list[dict[str, Any]],
    date_field: str,
) -> dict[str, Any] | None:
    """
    Return the most recent snapshot based on the supplied date field.

    Saved weekly and monthly snapshots use ISO-formatted dates,
    so string comparison safely preserves chronological order.
    """

    if not history:
        return None

    return max(
        history,
        key=lambda item: item.get(
            date_field,
            "",
        ),
    )


# ============================================================
# Recovery Insights dashboard
# ============================================================


def get_recovery_insights_data() -> dict[str, Any]:
    """Return structured deterministic Recovery Insights data."""

    profile = load_profile()
    step_work = load_step_work()
    active_goals = get_active_goals()

    checkins = get_recent_checkins(
        limit=7
    )

    weekly_history = (
        load_weekly_review_history()
    )

    monthly_history = (
        load_monthly_review_history()
    )

    latest_weekly = _latest_snapshot(
        weekly_history,
        "week_end",
    )

    latest_monthly = _latest_snapshot(
        monthly_history,
        "snapshot_date",
    )

    sobriety_date = profile.get(
        "sobriety_date"
    )

    current_step = step_work.get(
        "current_step",
        1,
    )

    open_assignments = [
        assignment
        for assignment in step_work.get(
            "assignments",
            [],
        )
        if (
            assignment.get("step")
            == current_step
            and not assignment.get(
                "completed",
                False,
            )
        )
    ]

    return {
        "sobriety_date": sobriety_date,
        "sobriety_days": calculate_sobriety_days(
            sobriety_date
        ),
        "current_step": current_step,
        "open_step_assignments": len(
            open_assignments
        ),
        "active_recovery_goals": len(
            active_goals
        ),
        "checkin_days_available": len(
            checkins
        ),
        "checkin_window_days": 7,
        "latest_weekly_snapshot": (
            latest_weekly
        ),
        "latest_monthly_snapshot": (
            latest_monthly
        ),
    }


def build_recovery_insights() -> str:
    """
    Build a deterministic longitudinal Recovery Insights summary.

    This combines locally stored recovery information from:

    - sobriety profile
    - Step Work
    - active recovery goals
    - recent Daily Check-Ins
    - latest Weekly Recovery Review
    - latest Monthly Recovery Review

    No AI interpretation occurs here.
    """

    # --------------------------------------------------------
    # Load current recovery data
    # --------------------------------------------------------

    profile = load_profile()
    step_work = load_step_work()
    active_goals = get_active_goals()

    checkins = get_recent_checkins(
        limit=7
    )

    weekly_history = (
        load_weekly_review_history()
    )

    monthly_history = (
        load_monthly_review_history()
    )

    # --------------------------------------------------------
    # Find latest saved review snapshots
    # --------------------------------------------------------

    latest_weekly = _latest_snapshot(
        weekly_history,
        "week_end",
    )

    latest_monthly = _latest_snapshot(
        monthly_history,
        "snapshot_date",
    )

    # --------------------------------------------------------
    # Current sobriety and Step Work state
    # --------------------------------------------------------

    sobriety_date = profile.get(
        "sobriety_date"
    )

    sobriety_days = calculate_sobriety_days(
        sobriety_date
    )

    current_step = step_work.get(
        "current_step",
        1,
    )

    open_assignments = [
        assignment
        for assignment in step_work.get(
            "assignments",
            [],
        )
        if (
            assignment.get("step")
            == current_step
            and not assignment.get(
                "completed",
                False,
            )
        )
    ]

    # --------------------------------------------------------
    # Core dashboard
    # --------------------------------------------------------

    lines = [
        "Recovery Insights",
        "=" * 50,
        "",
        "Current Recovery",
        "-" * 50,
        (
            f"Sobriety Days: {sobriety_days}"
            if sobriety_days is not None
            else "Sobriety Days: Not configured"
        ),
        f"Current Step: {current_step}",
        (
            "Open Step Assignments: "
            f"{len(open_assignments)}"
        ),
        (
            "Active Recovery Goals: "
            f"{len(active_goals)}"
        ),
        "",
        "Recent Activity",
        "-" * 50,
        (
            "Check-In Days Available: "
            f"{len(checkins)}/7"
        ),
    ]

    # --------------------------------------------------------
    # Latest Weekly Recovery Review
    # --------------------------------------------------------

    if latest_weekly:
        lines.extend(
            [
                "",
                "Latest Weekly Snapshot",
                "-" * 50,
                (
                    "Period: "
                    f"{latest_weekly.get('week_start', '?')} "
                    f"to "
                    f"{latest_weekly.get('week_end', '?')}"
                ),
                (
                    "Check-In Days: "
                    f"{latest_weekly.get('checkin_days', 0)}/7"
                ),
                (
                    "Journal Entries: "
                    f"{latest_weekly.get('journal_entries', 0)}"
                ),
            ]
        )

    else:
        lines.extend(
            [
                "",
                "Latest Weekly Snapshot",
                "-" * 50,
                "No saved weekly review available.",
            ]
        )

    # --------------------------------------------------------
    # Latest Monthly Recovery Review
    # --------------------------------------------------------

    if latest_monthly:
        lines.extend(
            [
                "",
                "Latest Monthly Snapshot",
                "-" * 50,
                (
                    "Snapshot Date: "
                    f"{latest_monthly.get('snapshot_date', '?')}"
                ),
                (
                    "Period: "
                    f"{latest_monthly.get('period_start', '?')} "
                    f"to "
                    f"{latest_monthly.get('period_end', '?')}"
                ),
                (
                    "Weekly Reviews Included: "
                    f"{latest_monthly.get('weekly_reviews_included', 0)}/4"
                ),
                (
                    "Check-In Days: "
                    f"{latest_monthly.get('checkin_days', 0)}"
                ),
                (
                    "Journal Entries: "
                    f"{latest_monthly.get('journal_entries', 0)}"
                ),
            ]
        )

    else:
        lines.extend(
            [
                "",
                "Latest Monthly Snapshot",
                "-" * 50,
                "No saved monthly review available.",
            ]
        )

    return "\n".join(
        lines
    )