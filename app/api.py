from fastapi import Depends, FastAPI

from app.auth import require_api_token

from app.recovery_insights import build_recovery_insights
from app.version import __version__
from app.goals import get_active_goals
from app.routines import get_active_routines
from app.sync import build_sync_payload


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

@app.get(
    "/recovery-insights",
    dependencies=[
        Depends(require_api_token)
    ],
)
def recovery_insights() -> dict[str, str]:
    """
    Return the current deterministic Recovery Insights summary.

    Authentication is required because this endpoint exposes
    personal recovery data.
    """

    return {
        "recovery_insights": build_recovery_insights(),
    }

@app.get(
    "/goals",
    dependencies=[
        Depends(require_api_token)
    ],
)
def active_goals() -> dict[str, object]:
    """Return active recovery goals."""

    goals = get_active_goals()

    return {
        "count": len(goals),
        "goals": goals,
    }


@app.get(
    "/routines",
    dependencies=[
        Depends(require_api_token)
    ],
)
def active_routines() -> dict[str, object]:
    """Return active recovery routines."""

    routines = get_active_routines()

    return {
        "count": len(routines),
        "routines": routines,
    }

@app.get(
    "/sync",
    dependencies=[
        Depends(require_api_token)
    ],
)
def sync_data() -> dict[str, object]:
    """
    Return the local Recovery Companion state for synchronization.

    Sprint 31 exposes the synchronization contract but does not
    transmit data to or store data in an external cloud service.
    """

    return build_sync_payload()