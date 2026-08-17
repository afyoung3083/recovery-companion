from fastapi import FastAPI

from app.recovery_insights import build_recovery_insights
from app.version import __version__
from app.goals import get_active_goals
from app.routines import get_active_routines

# ============================================================
# FastAPI application
# ============================================================

app = FastAPI(
    title="Recovery Companion API",
    version=__version__,
)


# ============================================================
# Health and metadata
# ============================================================

@app.get("/health")
def health() -> dict[str, str]:
    """Return a simple API health response."""

    return {
        "status": "ok",
        "version": __version__,
    }


# ============================================================
# Recovery data
# ============================================================

@app.get("/recovery-insights")
def recovery_insights() -> dict[str, str]:
    """
    Return the current deterministic Recovery Insights summary.

    This exposes existing application logic without adding AI
    interpretation or changing local persistence behavior.
    """

    return {
        "recovery_insights": build_recovery_insights(),
    }

@app.get("/goals")
def active_goals() -> dict[str, object]:
    """Return active recovery goals."""

    goals = get_active_goals()

    return {
        "count": len(goals),
        "goals": goals,
    }


@app.get("/routines")
def active_routines() -> dict[str, object]:
    """Return active recovery routines."""

    routines = get_active_routines()

    return {
        "count": len(routines),
        "routines": routines,
    }