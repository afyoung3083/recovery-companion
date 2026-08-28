from datetime import date

from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel

from app.auth import require_api_token
from app.backup import build_backup_payload
from app.data_ownership import delete_all_recovery_data
from app.dashboard import (
    build_dashboard,
    get_dashboard_data,
)
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
from app.profile import load_profile, set_sobriety_date
from app.recovery_insights import (
    build_recovery_insights,
    get_recovery_insights_data,
)
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
    update_contact,
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
    analyze_recovery_insights,
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

class ProfileSobrietyDateRequest(BaseModel):
    sobriety_date: str


class DataDeletionRequest(BaseModel):
    confirmation: str


class DailyCheckInRequest(BaseModel):
    prayer_meditation: bool = False
    recovery_contact: bool = False
    meeting: bool = False
    step_work: bool = False
    journal: bool = False
    service: bool = False
    note: str = ""


class AiReflectionSummaryRequest(BaseModel):
    summary: str
    checkin_count: int = 0


class RecoveryInsightsAiRequest(BaseModel):
    summary: str


class WeeklyReviewAiRequest(BaseModel):
    summary: str


class MonthlyReviewAiRequest(BaseModel):
    summary: str


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
# Dashboard and Profile
# ============================================================

@app.get(
    "/dashboard",
    dependencies=[
        Depends(require_api_token)
    ],
)
def dashboard() -> dict[str, object]:
    """Return deterministic Dashboard text and structured data."""

    return {
        "dashboard": build_dashboard(),
        "dashboard_data": get_dashboard_data(),
    }


@app.get(
    "/profile",
    dependencies=[
        Depends(require_api_token)
    ],
)
def profile() -> dict[str, object]:
    """Return the locally stored recovery profile."""

    return {
        "profile": load_profile(),
    }


@app.put(
    "/profile/sobriety-date",
    dependencies=[
        Depends(require_api_token)
    ],
)
def update_profile_sobriety_date(
    request: ProfileSobrietyDateRequest,
) -> dict[str, object]:
    """Validate and update the profile sobriety date."""

    sobriety_date = request.sobriety_date.strip()

    try:
        parsed_date = date.fromisoformat(
            sobriety_date
        )
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail="Sobriety date must use YYYY-MM-DD format.",
        ) from error

    if parsed_date > date.today():
        raise HTTPException(
            status_code=400,
            detail="Sobriety date cannot be in the future.",
        )

    updated_profile = set_sobriety_date(
        sobriety_date
    )

    return {
        "profile": updated_profile,
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
def recovery_insights() -> dict[str, object]:
    """
    Return deterministic Recovery Insights text and structured data.

    Authentication is required because this endpoint exposes
    personal recovery data.
    """

    return {
        "recovery_insights": build_recovery_insights(),
        "recovery_insights_data": get_recovery_insights_data(),
    }


@app.post(
    "/recovery-insights/ai-reflection",
    dependencies=[
        Depends(require_api_token)
    ],
)
def recovery_insights_ai_reflection(
    request: RecoveryInsightsAiRequest | None = None,
) -> dict[str, str]:
    """
    Generate an optional AI reflection on Recovery Insights.

    Local-first clients may provide the deterministic summary they
    constructed from authoritative on-device recovery data.

    Older clients may omit the request body, preserving the original
    server-side summary behavior.

    Only the supplied deterministic summary is sent to the AI.
    """

    if request is not None:
        insights_text = request.summary.strip()

        if not insights_text:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Recovery Insights summary cannot be empty."
                ),
            )

    else:
        insights_text = build_recovery_insights()

    try:
        reflection = analyze_recovery_insights(
            insights_text
        )
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail=(
                "Unable to generate Recovery Insights reflection."
            ),
        ) from error

    return {
        "reflection": reflection,
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
# Data Ownership
# ============================================================

@app.get(
    "/data-ownership/export",
    dependencies=[
        Depends(require_api_token)
    ],
)
def export_recovery_data() -> dict[str, object]:
    """
    Return a complete user-owned export of local recovery data.

    The export uses the existing Recovery Companion backup format,
    including its integrity hash. This endpoint does not create an
    additional server-side backup file.
    """

    return {
        "export": build_backup_payload(),
    }


@app.delete(
    "/data-ownership",
    dependencies=[
        Depends(require_api_token)
    ],
)
def delete_recovery_data(
    request: DataDeletionRequest,
) -> dict[str, object]:
    """
    Permanently delete local Recovery Companion recovery data.

    An exact confirmation phrase is required. Recovery Companion
    backups are deleted with the active recovery data.
    """

    try:
        return delete_all_recovery_data(
            request.confirmation
        )
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error


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
def daily_checkin_ai_reflection(
    request: AiReflectionSummaryRequest | None = None,
) -> dict[str, object]:
    """
    Analyze recent Daily Recovery Check-In information.

    Local-first clients may explicitly provide the deterministic
    summary they just constructed from authoritative on-device data.
    Older clients may omit the body; in that case the API preserves
    the original behavior and builds the summary from server data.

    Only the summary is sent to the AI. The reflection is not
    persisted automatically.
    """

    if request is not None:
        checkin_text = request.summary.strip()

        if not checkin_text:
            raise HTTPException(
                status_code=400,
                detail="Check-in summary cannot be empty.",
            )

        if (
            request.checkin_count < 1
            or request.checkin_count > 7
        ):
            raise HTTPException(
                status_code=400,
                detail=(
                    "Check-in count must be between 1 and 7."
                ),
            )

        checkin_count = request.checkin_count

    else:
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

        checkin_count = len(checkins)

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
        "checkin_count": checkin_count,
        "reflection": reflection,
    }


class JournalAiReflectionRequest(BaseModel):
    text: str


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
    request: JournalAiReflectionRequest | None = None,
) -> dict[str, object]:
    """
    Analyze one explicitly selected journal entry.

    Local-first clients supply the exact selected entry text.
    Older clients may omit the body; in that case the API preserves
    the original server-side journal-ID lookup behavior.

    The reflection is not persisted automatically.
    """

    if request is not None:
        entry_text = request.text.strip()

        if not entry_text:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Journal entry has no text to analyze."
                ),
            )

    else:
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
                detail=(
                    "Journal entry has no text to analyze."
                ),
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
    "/fellowship/{contact_id}",
    dependencies=[
        Depends(require_api_token)
    ],
)
def update_fellowship_contact(
    contact_id: int,
    request: FellowshipContactRequest,
) -> dict[str, object]:
    """Update a fellowship contact."""

    try:
        contact = update_contact(
            contact_id=contact_id,
            handle=request.handle,
            contact_type=request.contact_type,
            contact_method=request.contact_method,
            notes=request.notes,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error

    if contact is None:
        raise HTTPException(
            status_code=404,
            detail="Fellowship contact not found.",
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
def weekly_review_ai_reflection(
    request: WeeklyReviewAiRequest | None = None,
) -> dict[str, str]:
    """
    Generate an optional AI reflection on a Weekly Recovery Review.

    Local-first clients may explicitly provide the deterministic
    review constructed from authoritative on-device recovery data.

    Older clients may omit the request body, preserving the original
    server-side review behavior.
    """

    if request is not None:
        review_text = request.summary.strip()

        if not review_text:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Weekly Review summary cannot be empty."
                ),
            )

    else:
        review_text = build_weekly_review()

    try:
        reflection = analyze_weekly_review(
            review_text
        )
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail=(
                "Unable to generate Weekly Review reflection."
            ),
        ) from error

    return {
        "review": review_text,
        "reflection": reflection,
    }


@app.post(
    "/monthly-review/ai-reflection",
    dependencies=[
        Depends(require_api_token)
    ],
)
def create_monthly_review_ai_reflection(
    request: MonthlyReviewAiRequest | None = None,
) -> dict[str, str]:
    """
    Generate an AI reflection for the current Monthly Recovery Review.

    Local-first clients may explicitly supply the deterministic
    monthly summary built from authoritative on-device recovery data.

    Older clients may omit the request body and preserve the original
    server-side Monthly Review behavior.
    """

    if request is not None:
        review = request.summary.strip()

        if not review:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Monthly Review summary cannot be empty."
                ),
            )
    else:
        review = build_monthly_review()

    try:
        reflection = analyze_monthly_review(
            review
        )
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail=(
                "Unable to generate Monthly Review reflection."
            ),
        ) from error

    return {
        "review": review,
        "reflection": reflection,
    }
