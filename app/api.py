from datetime import date

from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel

from app.auth import require_api_token
from app.daily_checkin import (
    format_checkin_history,
    format_checkin_trends,
    get_checkin_for_date,
    get_recent_checkins,
    save_daily_checkin,
)
from app.goals import (
    add_goal,
    complete_goal,
    get_active_goals,
    reactivate_goal,
)
from app.journal import (
    add_entry,
    load_entries,
    search_entries,
)
from app.recovery_insights import build_recovery_insights
from app.routines import (
    add_routine,
    get_active_routines,
    set_routine_active,
)
from app.step_work import (
    add_assignment,
    complete_assignment,
    load_step_work,
    set_current_step,
)
from app.sync import build_sync_payload
from app.version import __version__
from app.fellowship import (
    add_contact,
    load_contacts,
    recommend_contacts,
    set_contact_active,
)
from app.weekly_review import (
    build_weekly_review,
    compare_latest_weekly_reviews,
    load_weekly_review_history,
    save_weekly_review_snapshot,
)
from app.monthly_review import (
    build_monthly_review,
    compare_latest_monthly_reviews,
    load_monthly_review_history,
    save_monthly_review_snapshot,
)
from app.recovery_engine import (
    analyze_checkin_trends,
    analyze_journal_entry,
    analyze_monthly_review,
    analyze_weekly_review,
    respond_to_user,
)

# ============================================================
# FastAPI application
# ============================================================

app = FastAPI(
    title="Recovery Companion API",
    version=__version__,
)


# ============================================================
# Pydantic Request models
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

class FellowshipContactRequest(BaseModel):
    handle: str
    contact_type: str
    contact_method: str = ""
    notes: str = ""


class FellowshipContactActiveRequest(BaseModel):
    active: bool

class GoalRequest(BaseModel):
    text: str
    area: str
    target_date: str = ""


class RoutineRequest(BaseModel):
    text: str
    area: str
    frequency: str
    day_of_week: str = ""


class ActiveStateRequest(BaseModel):
    active: bool


class ChatMessageRequest(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    conversation: list[ChatMessageRequest]


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
# Chat
# ============================================================

@app.post(
    "/chat",
    dependencies=[
        Depends(require_api_token)
    ],
)
def chat(
    request: ChatRequest,
) -> dict[str, str]:
    """
    Generate a Recovery Companion response for an ordered conversation.

    Chat history is supplied explicitly by the client for each request.
    The API does not persist conversation history.
    """

    if not request.conversation:
        raise HTTPException(
            status_code=400,
            detail="Conversation must contain at least one message.",
        )

    conversation: list[dict[str, str]] = []
    previous_role: str | None = None

    for message in request.conversation:
        role = message.role.strip().lower()

        if role not in {"user", "assistant"}:
            raise HTTPException(
                status_code=400,
                detail="Chat message role must be user or assistant.",
            )

        if not message.content.strip():
            raise HTTPException(
                status_code=400,
                detail="Chat message content cannot be empty.",
            )

        if previous_role == role:
            raise HTTPException(
                status_code=400,
                detail="Chat message roles must alternate.",
            )

        conversation.append(
            {
                "role": role,
                "content": message.content,
            }
        )

        previous_role = role

    if conversation[0]["role"] != "user":
        raise HTTPException(
            status_code=400,
            detail="Conversation must begin with a user message.",
        )

    if conversation[-1]["role"] != "user":
        raise HTTPException(
            status_code=400,
            detail="Conversation must end with a user message.",
        )

    try:
        response = respond_to_user(
            conversation
        )
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail=(
                "Unable to generate a Recovery Companion response."
            ),
        ) from error

    return {
        "response": response,
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


@app.post(
    "/goals",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_goal(
    request: GoalRequest,
) -> dict[str, object]:
    """Create a new recovery goal."""

    try:
        goal = add_goal(
            text=request.text,
            area=request.area,
            target_date=request.target_date,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    return {
        "goal": goal,
    }


@app.put(
    "/goals/{goal_id}/complete",
    dependencies=[
        Depends(require_api_token)
    ],
)
def mark_goal_complete(
    goal_id: int,
) -> dict[str, object]:
    """Mark a recovery goal complete."""

    goal = complete_goal(
        goal_id
    )

    if goal is None:
        raise HTTPException(
            status_code=404,
            detail="Recovery goal not found.",
        )

    return {
        "goal": goal,
    }


@app.put(
    "/goals/{goal_id}/reactivate",
    dependencies=[
        Depends(require_api_token)
    ],
)
def reactivate_recovery_goal(
    goal_id: int,
) -> dict[str, object]:
    """Reactivate a completed recovery goal."""

    goal = reactivate_goal(
        goal_id
    )

    if goal is None:
        raise HTTPException(
            status_code=404,
            detail="Recovery goal not found.",
        )

    return {
        "goal": goal,
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

@app.post(
    "/routines",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_routine(
    request: RoutineRequest,
) -> dict[str, object]:
    """Create a new recovery routine."""

    try:
        routine = add_routine(
            text=request.text,
            area=request.area,
            frequency=request.frequency,
            day_of_week=request.day_of_week,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    return {
        "routine": routine,
    }


@app.put(
    "/routines/{routine_id}/active",
    dependencies=[
        Depends(require_api_token)
    ],
)
def update_routine_active(
    routine_id: int,
    request: ActiveStateRequest,
) -> dict[str, object]:
    """Activate or deactivate a recovery routine."""

    routine = set_routine_active(
        routine_id=routine_id,
        active=request.active,
    )

    if routine is None:
        raise HTTPException(
            status_code=404,
            detail="Recovery routine not found.",
        )

    return {
        "routine": routine,
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


@app.post(
    "/daily-checkin/ai-reflection",
    dependencies=[
        Depends(require_api_token)
    ],
)
def daily_checkin_ai_reflection() -> dict[str, object]:
    """
    Analyze the seven most recent saved Daily Recovery Check-Ins.

    The deterministic history and trend summary is constructed
    locally. Only that summary is sent to the AI, and the
    reflection is not persisted automatically.
    """

    checkins = get_recent_checkins(
        limit=7
    )

    if not checkins:
        raise HTTPException(
            status_code=404,
            detail=(
                "No recent check-ins available to analyze."
            ),
        )

    history_text = format_checkin_history(
        checkins
    )

    trends_text = format_checkin_trends(
        checkins
    )

    checkin_text = (
        f"{history_text}\n\n"
        f"{trends_text}"
    )

    try:
        reflection = analyze_checkin_trends(
            checkin_text
        )
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail=(
                "Unable to generate check-in reflection."
            ),
        ) from error

    return {
        "checkin_count": len(checkins),
        "reflection": reflection,
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


@app.post(
    "/journal/{entry_id}/ai-reflection",
    dependencies=[
        Depends(require_api_token)
    ],
)
def journal_ai_reflection(
    entry_id: int,
) -> dict[str, object]:
    """
    Analyze one explicitly selected journal entry.

    Only the selected entry text is sent to the AI.
    The analysis is not persisted automatically.
    """

    entries = load_entries()

    selected_entry = next(
        (
            entry
            for entry in entries
            if entry.get("id") == entry_id
        ),
        None,
    )

    if selected_entry is None:
        raise HTTPException(
            status_code=404,
            detail="Journal entry not found.",
        )

    entry_text = str(
        selected_entry.get(
            "text",
            "",
        )
    ).strip()

    if not entry_text:
        raise HTTPException(
            status_code=400,
            detail="Journal entry has no text to analyze.",
        )

    try:
        reflection = analyze_journal_entry(
            entry_text
        )
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail=(
                "Unable to generate journal reflection."
            ),
        ) from error

    return {
        "entry_id": entry_id,
        "reflection": reflection,
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

@app.get(
    "/fellowship",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_fellowship_contacts() -> dict[str, object]:
    """Return all fellowship contacts."""

    contacts = load_contacts()

    return {
        "count": len(contacts),
        "contacts": contacts,
    }


@app.post(
    "/fellowship",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_fellowship_contact(
    request: FellowshipContactRequest,
) -> dict[str, object]:
    """Create a fellowship contact."""

    contact = add_contact(
        handle=request.handle,
        contact_type=request.contact_type,
        contact_method=request.contact_method,
        notes=request.notes,
    )

    return {
        "contact": contact,
    }


@app.put(
    "/fellowship/{contact_id}/active",
    dependencies=[
        Depends(require_api_token)
    ],
)
def update_fellowship_contact_active(
    contact_id: int,
    request: FellowshipContactActiveRequest,
) -> dict[str, object]:
    """Activate or deactivate a fellowship contact."""

    contact = set_contact_active(
        contact_id=contact_id,
        active=request.active,
    )

    if contact is None:
        raise HTTPException(
            status_code=404,
            detail="Fellowship contact not found.",
        )

    return {
        "contact": contact,
    }


@app.get(
    "/fellowship/recommended",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_recommended_fellowship_contacts(
    limit: int = 3,
) -> dict[str, object]:
    """Return prioritized active fellowship contacts."""

    contacts = load_contacts()

    recommended = recommend_contacts(
        contacts=contacts,
        limit=limit,
    )

    return {
        "count": len(recommended),
        "contacts": recommended,
    }

@app.get(
    "/weekly-review/current",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_current_weekly_review() -> dict[str, str]:
    """Return the current unsaved weekly recovery review."""

    return {
        "review": build_weekly_review(),
    }


@app.post(
    "/weekly-review/snapshot",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_weekly_review_snapshot() -> dict[str, object]:
    """Save or replace the current weekly review snapshot."""

    snapshot = save_weekly_review_snapshot()

    return {
        "snapshot": snapshot,
    }


@app.get(
    "/weekly-review/history",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_weekly_review_history() -> dict[str, object]:
    """Return saved weekly review snapshots."""

    history = load_weekly_review_history()

    return {
        "count": len(history),
        "history": history,
    }


@app.get(
    "/weekly-review/comparison",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_weekly_review_comparison() -> dict[str, str]:
    """Compare the two most recent saved weekly reviews."""

    history = load_weekly_review_history()

    return {
        "comparison": compare_latest_weekly_reviews(
            history
        ),
    }

@app.get(
    "/monthly-review/current",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_current_monthly_review() -> dict[str, str]:
    """Return the current rolling four-week recovery review."""

    return {
        "review": build_monthly_review(),
    }


@app.post(
    "/monthly-review/snapshot",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_monthly_review_snapshot() -> dict[str, object]:
    """Save or replace the current monthly review snapshot."""

    try:
        snapshot = save_monthly_review_snapshot()
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    return {
        "snapshot": snapshot,
    }


@app.get(
    "/monthly-review/history",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_monthly_review_history() -> dict[str, object]:
    """Return saved monthly review snapshots."""

    history = load_monthly_review_history()

    return {
        "count": len(history),
        "history": history,
    }


@app.get(
    "/monthly-review/comparison",
    dependencies=[
        Depends(require_api_token)
    ],
)
def get_monthly_review_comparison() -> dict[str, str]:
    """Compare the two most recent saved monthly reviews."""

    history = load_monthly_review_history()

    return {
        "comparison": compare_latest_monthly_reviews(
            history
        ),
    }

@app.post(
    "/weekly-review/ai-reflection",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_weekly_review_ai_reflection() -> dict[str, str]:
    """
    Generate an AI reflection for the current Weekly Recovery Review.

    Calling this endpoint represents an explicit user request to share
    the deterministic weekly summary with the AI analysis layer.
    """

    review = build_weekly_review()

    reflection = analyze_weekly_review(
        review
    )

    return {
        "review": review,
        "reflection": reflection,
    }


@app.post(
    "/monthly-review/ai-reflection",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_monthly_review_ai_reflection() -> dict[str, str]:
    """
    Generate an AI reflection for the current Monthly Recovery Review.

    Calling this endpoint represents an explicit user request to share
    the deterministic monthly summary with the AI analysis layer.
    """

    review = build_monthly_review()

    reflection = analyze_monthly_review(
        review
    )

    return {
        "review": review,
        "reflection": reflection,
    }