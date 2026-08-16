from typing import Any

from app.daily_checkin import get_recent_checkins
from app.dashboard import calculate_sobriety_days
from app.monthly_review import load_monthly_review_history
from app.profile import load_profile
from app.step_work import load_step_work
from app.weekly_review import load_weekly_review_history


def _latest_snapshot(
    history: list[dict[str, Any]],
    date_field: str,
) -> dict[str, Any] | None:
    """Return the most recent snapshot using the supplied date field."""

    if not history:
        return None

    return max(
        history,
        key=lambda item: item.get(
            date_field,
            "",
        ),
    )


def build_recovery_insights() -> str:
    """
    Build a deterministic longitudinal Recovery Insights summary.

    This dashboard combines local daily, Step Work, weekly, and
    monthly data without asking the AI to interpret it.
    """

    profile = load_profile()
    step_work = load_step_work()
    checkins = get_recent_checkins(limit=7)

    weekly_history = load_weekly_review_history()
    monthly_history = load_monthly_review_history()

    latest_weekly = _latest_snapshot(
        weekly_history,
        "week_end",
    )

    latest_monthly = _latest_snapshot(
        monthly_history,
        "snapshot_date",
    )

    sobriety_date = profile.get("sobriety_date")

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
            assignment.get("step") == current_step
            and not assignment.get(
                "completed",
                False,
            )
        )
    ]

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
        "",
        "Recent Activity",
        "-" * 50,
        f"Check-In Days Available: {len(checkins)}/7",
    ]

    if latest_weekly:
        lines.extend(
            [
                "",
                "Latest Weekly Snapshot",
                "-" * 50,
                (
                    f"Period: "
                    f"{latest_weekly.get('week_start', '?')} "
                    f"to {latest_weekly.get('week_end', '?')}"
                ),
                (
                    f"Check-In Days: "
                    f"{latest_weekly.get('checkin_days', 0)}/7"
                ),
                (
                    f"Journal Entries: "
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

    if latest_monthly:
        lines.extend(
            [
                "",
                "Latest Monthly Snapshot",
                "-" * 50,
                (
                    f"Snapshot Date: "
                    f"{latest_monthly.get('snapshot_date', '?')}"
                ),
                (
                    f"Period: "
                    f"{latest_monthly.get('period_start', '?')} "
                    f"to {latest_monthly.get('period_end', '?')}"
                ),
                (
                    "Weekly Reviews Included: "
                    f"{latest_monthly.get('weekly_reviews_included', 0)}/4"
                ),
                (
                    f"Check-In Days: "
                    f"{latest_monthly.get('checkin_days', 0)}"
                ),
                (
                    f"Journal Entries: "
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

    return "\n".join(lines)