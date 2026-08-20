from datetime import date

from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel

from app.auth import require_api_token
from app.daily_checkin import (
    get_checkin_for_date,
    save_daily_checkin,
)
from app.goals import get_active_goals
from app.journal import (
    add_entry,
    load_entries,
    search_entries,
)
from app.recovery_insights import build_recovery_insights
from app.routines import get_active_routines
from app.step_work import (
    add_assignment,
    complete_assignment,
    load_step_work,
    set_current_step,
)
from app.sync import build_sync_payload
from app.version import __version__


# ============================================================
# FastAPI application
# ============================================================

app = FastAPI(
    title="Recovery Companion API",
    version=__version__,
)


# ============================================================
# Request models
# ============================================================

class DailyCheckInRequest(BaseModel):
    prayer_meditation: bool = False
    recovery_contact: bool = False
    meeting: bool = False
    step_work: bool = False
    journal: bool = False
    service: bool = False
    note: str = ""


class JournalEntryRequest(BaseModel):
    text: str
    tags: list[str] = []


class StepNumberRequest(BaseModel):
    step_number: int


class StepAssignmentRequest(BaseModel):
    text: str


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
# Recovery Insights
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


# ============================================================
# Goals
# ============================================================

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


# ============================================================
# Routines
# ============================================================

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


# ============================================================
# Synchronization
# ============================================================

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


# ============================================================
# Daily Check-In
# ============================================================

@app.get(
    "/daily-checkin/today",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_today_checkin() -> dict[str, object]:
    """Return today's Daily Recovery Check-In."""

    today = date.today().isoformat()

    checkin = get_checkin_for_date(
        today
    )

    return {
        "date": today,
        "checkin": checkin,
    }


@app.put(
    "/daily-checkin/today",
    dependencies=[
        Depends(require_api_token)
    ],
)
def update_today_checkin(
    request: DailyCheckInRequest,
) -> dict[str, object]:
    """Create or update today's Daily Recovery Check-In."""

    checkin = save_daily_checkin(
        values={
            "prayer_meditation": request.prayer_meditation,
            "recovery_contact": request.recovery_contact,
            "meeting": request.meeting,
            "step_work": request.step_work,
            "journal": request.journal,
            "service": request.service,
        },
        note=request.note,
    )

    return {
        "checkin": checkin,
    }


# ============================================================
# Journal
# ============================================================

@app.get(
    "/journal",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_journal_entries() -> dict[str, object]:
    """Return all locally stored journal entries."""

    entries = load_entries()

    return {
        "count": len(entries),
        "entries": entries,
    }


@app.post(
    "/journal",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_journal_entry(
    request: JournalEntryRequest,
) -> dict[str, object]:
    """Create a new local journal entry."""

    entry = add_entry(
        text=request.text,
        tags=request.tags,
    )

    return {
        "entry": entry,
    }


@app.get(
    "/journal/search",
    dependencies=[
        Depends(require_api_token)
    ],
)
def search_journal_entries(
    q: str,
) -> dict[str, object]:
    """Search journal entries by text or tag."""

    entries = load_entries()

    matches = search_entries(
        entries=entries,
        query=q,
    )

    return {
        "count": len(matches),
        "entries": matches,
    }


# ============================================================
# Step Work
# ============================================================

@app.get(
    "/step-work",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_step_work() -> dict[str, object]:
    """Return the current Step Work state."""

    return {
        "step_work": load_step_work(),
    }


@app.put(
    "/step-work/current-step",
    dependencies=[
        Depends(require_api_token)
    ],
)
def update_current_step(
    request: StepNumberRequest,
) -> dict[str, object]:
    """Change the current Twelve-Step step."""

    step_work = set_current_step(
        request.step_number
    )

    return {
        "step_work": step_work,
    }


@app.post(
    "/step-work/assignments",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_step_assignment(
    request: StepAssignmentRequest,
) -> dict[str, object]:
    """Add an assignment to the current Step."""

    assignment = add_assignment(
        request.text
    )

    return {
        "assignment": assignment,
    }


@app.put(
    "/step-work/assignments/{assignment_id}/complete",
    dependencies=[
        Depends(require_api_token)
    ],
)
def mark_step_assignment_complete(
    assignment_id: int,
) -> dict[str, object]:
    """Mark a Step Work assignment complete."""

    assignment = complete_assignment(
        assignment_id
    )

    if assignment is None:
        raise HTTPException(
            status_code=404,
            detail="Step Work assignment not found.",
        )

    return {
        "assignment": assignment,
    }