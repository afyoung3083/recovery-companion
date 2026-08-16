from collections.abc import Callable
from datetime import date

# ============================================================
# Application modules
# ============================================================

from app.daily_checkin import (
    format_checkin,
    format_checkin_history,
    format_checkin_trends,
    get_checkin_for_date,
    get_recent_checkins,
    save_daily_checkin,
)
from app.dashboard import build_dashboard
from app.fellowship import (
    add_contact,
    format_contacts,
    load_contacts,
    recommend_contacts,
    set_contact_active,
)
from app.journal import (
    add_entry,
    filter_entries_by_tag,
    format_entries,
    load_entries,
    search_entries,
)
from app.monthly_review import (
    build_monthly_review,
    compare_latest_monthly_reviews,
    format_monthly_review_history,
    load_monthly_review_history,
    save_monthly_review_snapshot,
)
from app.profile import set_sobriety_date
from app.recovery_engine import (
    analyze_checkin_trends,
    analyze_journal_entry,
    analyze_monthly_review,
    analyze_step_work,
    analyze_weekly_comparison,
    analyze_weekly_review,
    respond_to_user,
    analyze_monthly_comparison,
    analyze_recovery_insights,
)
from app.step_work import (
    add_assignment,
    add_step_note,
    complete_assignment,
    format_step_work,
    load_step_work,
    set_current_step,
)
from app.version import __version__
from app.weekly_review import (
    build_weekly_review,
    compare_latest_weekly_reviews,
    format_weekly_review_history,
    load_weekly_review_history,
    save_weekly_review_snapshot,
)
from app.recovery_insights import build_recovery_insights
from app.goals import (
    add_goal,
    complete_goal,
    format_goals,
    get_active_goals,
    load_goals,
    reactivate_goal,
)

# ============================================================
# Menu framework
# ============================================================

# Every menu item is simply:
#
#     ("Label shown to user", function_to_run)
#
# This means new features can usually be added to a menu with one
# line instead of manually renumbering a large elif chain.
MenuAction = Callable[[], None]
MenuItem = tuple[str, MenuAction]


def run_menu(
    title: str,
    items: list[MenuItem],
    *,
    final_label: str = "Back",
) -> None:
    """
    Display and run a reusable numbered CLI menu.

    The final numbered choice automatically returns to the caller.

    For submenus this means "Back".

    The main menu also uses this behavior, but its final choice is
    labeled "Exit". Returning from the main menu causes main() to end.
    """

    while True:
        print()
        print(title)
        print("=" * 50)

        for index, (label, _) in enumerate(
            items,
            start=1,
        ):
            print(f"{index}. {label}")

        final_choice = len(items) + 1
        print(f"{final_choice}. {final_label}")
        print()

        choice = input(
            "Choose an option: "
        ).strip()

        if not choice.isdigit():
            print(
                f"Please choose 1 through {final_choice}."
            )
            continue

        choice_number = int(choice)

        if choice_number == final_choice:
            return

        if not 1 <= choice_number <= len(items):
            print(
                f"Please choose 1 through {final_choice}."
            )
            continue

        # Convert the user's 1-based menu choice to the list's
        # 0-based index and execute the associated function.
        _, action = items[
            choice_number - 1
        ]

        action()


# ============================================================
# Chat
# ============================================================

def run_chat() -> None:
    """Run the conversational Recovery Companion chat."""

    conversation: list[dict[str, str]] = []

    print()
    print("Recovery Companion Chat")
    print("=" * 50)
    print("Type 'back' to return to the main menu.")
    print()

    while True:
        user_message = input(
            "You: "
        ).strip()

        if user_message.lower() == "back":
            print()
            return

        if not user_message:
            print("Please enter a message.")
            continue

        conversation.append(
            {
                "role": "user",
                "content": user_message,
            }
        )

        try:
            response = respond_to_user(
                conversation
            )
        except Exception as error:
            print()
            print(f"Error: {error}")
            print()

            # Remove the unsent user turn so the conversation
            # remains internally consistent.
            conversation.pop()
            continue

        conversation.append(
            {
                "role": "assistant",
                "content": response,
            }
        )

        print()
        print("Recovery Companion:")
        print(response)
        print()


# ============================================================
# Journal
# ============================================================

def write_journal_entry() -> None:
    """Create and save a local journal entry."""

    print()
    print("New Journal Entry")
    print("=" * 50)
    print("Enter your journal entry on one line.")
    print()

    text = input(
        "Journal: "
    ).strip()

    if not text:
        print("Journal entry was not saved.")
        print()
        return

    print()

    tag_input = input(
        "Tags (comma-separated, optional): "
    ).strip()

    tags = [
        tag.strip().lower()
        for tag in tag_input.split(",")
        if tag.strip()
    ]

    entry = add_entry(
        text=text,
        tags=tags,
    )

    print()
    print(
        f"Journal entry {entry['id']} saved."
    )
    print()


def view_journal() -> None:
    """Display all saved journal entries."""

    print()
    print("Journal Entries")
    print("=" * 50)
    print(
        format_entries(
            load_entries()
        )
    )
    print()


def search_journal() -> None:
    """Search journal text and tags."""

    print()
    print("Search Journal")
    print("=" * 50)

    query = input(
        "Search term or tag: "
    ).strip()

    if not query:
        print("No search term entered.")
        print()
        return

    matches = search_entries(
        entries=load_entries(),
        query=query,
    )

    print()
    print(
        format_entries(matches)
    )
    print()


def filter_journal_by_tag() -> None:
    """Show journal entries containing a specific tag."""

    print()
    print("Filter Journal by Tag")
    print("=" * 50)

    tag = input(
        "Tag: "
    ).strip()

    if not tag:
        print("No tag entered.")
        print()
        return

    matches = filter_entries_by_tag(
        entries=load_entries(),
        tag=tag,
    )

    print()
    print(
        format_entries(matches)
    )
    print()


def analyze_journal() -> None:
    """Send one explicitly selected journal entry to the AI."""

    print()
    print("Analyze Journal Entry")
    print("=" * 50)

    entries = load_entries()

    if not entries:
        print("No journal entries available.")
        print()
        return

    print(
        format_entries(entries)
    )
    print()

    entry_id_input = input(
        "Entry ID to analyze: "
    ).strip()

    if not entry_id_input.isdigit():
        print(
            "Please enter a valid journal entry ID."
        )
        print()
        return

    entry_id = int(
        entry_id_input
    )

    selected_entry = next(
        (
            entry
            for entry in entries
            if entry.get("id") == entry_id
        ),
        None,
    )

    if selected_entry is None:
        print("Journal entry not found.")
        print()
        return

    print()
    print(
        "Only this selected entry will be sent to the AI."
    )

    confirm = input(
        "Analyze this entry? (y/n): "
    ).strip().lower()

    if confirm != "y":
        print("Analysis cancelled.")
        print()
        return

    print()
    print(
        "Recovery Companion Journal Analysis:"
    )

    print(
        analyze_journal_entry(
            selected_entry.get(
                "text",
                "",
            )
        )
    )

    print()


def run_journal_menu() -> None:
    """Run the Journal submenu."""

    run_menu(
        "Journal",
        [
            (
                "Write Journal Entry",
                write_journal_entry,
            ),
            (
                "View Journal",
                view_journal,
            ),
            (
                "Search Journal",
                search_journal,
            ),
            (
                "Filter Journal by Tag",
                filter_journal_by_tag,
            ),
            (
                "Analyze Journal Entry",
                analyze_journal,
            ),
        ],
    )


# ============================================================
# Step Work
# ============================================================

def view_step_work() -> None:
    """Display the user's current Step Work."""

    print()
    print("Step Work")
    print("=" * 50)
    print(
        format_step_work(
            load_step_work()
        )
    )
    print()


def change_current_step() -> None:
    """Change the locally stored current Step."""

    print()

    step_input = input(
        "Current Step (1-12): "
    ).strip()

    if not step_input.isdigit():
        print(
            "Please enter a number from 1 to 12."
        )
        print()
        return

    step_number = int(
        step_input
    )

    try:
        set_current_step(
            step_number
        )
    except ValueError as error:
        print(error)
        print()
        return

    print(
        f"Current Step set to {step_number}."
    )
    print()


def create_step_assignment() -> None:
    """Add an assignment to the current Step."""

    print()

    text = input(
        "Assignment: "
    ).strip()

    if not text:
        print(
            "Assignment was not saved."
        )
        print()
        return

    assignment = add_assignment(
        text
    )

    print(
        f"Assignment {assignment['id']} added "
        f"to Step {assignment['step']}."
    )
    print()


def mark_step_assignment_complete() -> None:
    """Mark a Step assignment complete by ID."""

    print()

    assignment_input = input(
        "Assignment ID: "
    ).strip()

    if not assignment_input.isdigit():
        print(
            "Please enter a valid assignment ID."
        )
        print()
        return

    assignment = complete_assignment(
        int(assignment_input)
    )

    if assignment is None:
        print("Assignment not found.")
    else:
        print(
            f"Assignment {assignment['id']} "
            "marked complete."
        )

    print()


def create_step_note() -> None:
    """Add a note to the current Step."""

    print()

    text = input(
        "Step note: "
    ).strip()

    if not text:
        print("Note was not saved.")
        print()
        return

    note = add_step_note(
        text
    )

    print(
        f"Note {note['id']} added "
        f"to Step {note['step']}."
    )
    print()


def analyze_current_step_work() -> None:
    """Explicitly send the current Step Work summary to the AI."""

    print()
    print("Analyze Current Step Work")
    print("=" * 50)

    step_work = load_step_work()

    step_work_text = format_step_work(
        step_work
    )

    print(
        step_work_text
    )
    print()

    print(
        "Only the current Step Work summary shown above "
        "will be sent to the AI."
    )

    confirm = input(
        "Analyze this Step Work? (y/n): "
    ).strip().lower()

    if confirm != "y":
        print("Analysis cancelled.")
        print()
        return

    print()
    print(
        "Recovery Companion Step Work Analysis:"
    )

    print(
        analyze_step_work(
            step_work_text
        )
    )

    print()


def run_step_work_menu() -> None:
    """Run the Step Work submenu."""

    run_menu(
        "Step Work",
        [
            (
                "View Step Work",
                view_step_work,
            ),
            (
                "Change Current Step",
                change_current_step,
            ),
            (
                "Add Assignment",
                create_step_assignment,
            ),
            (
                "Mark Assignment Complete",
                mark_step_assignment_complete,
            ),
            (
                "Add Step Note",
                create_step_note,
            ),
            (
                "Analyze Current Step Work",
                analyze_current_step_work,
            ),
        ],
    )


# ============================================================
# Fellowship
# ============================================================

def view_fellowship_contacts() -> None:
    """Display locally stored fellowship contacts."""

    print()
    print("Fellowship Contacts")
    print("=" * 50)
    print(
        format_contacts(
            load_contacts()
        )
    )
    print()


def create_fellowship_contact() -> None:
    """Add a new fellowship/support contact."""

    print()
    print("Add Fellowship Contact")
    print("=" * 50)

    handle = input(
        "Handle or name: "
    ).strip()

    if not handle:
        print("Contact was not saved.")
        print()
        return

    contact_type = input(
        "Type (sponsor, sponsee, dsr, fellowship, "
        "therapist, clergy, family, other): "
    ).strip()

    contact_method = input(
        "Contact method (optional): "
    ).strip()

    notes = input(
        "Notes (optional): "
    ).strip()

    try:
        contact = add_contact(
            handle=handle,
            contact_type=contact_type,
            contact_method=contact_method,
            notes=notes,
        )

    except ValueError as error:
        print(error)
        print()
        return

    print()

    print(
        f"Contact {contact['id']} saved: "
        f"{contact['handle']} "
        f"({contact['contact_type']})."
    )

    print()


def change_fellowship_contact_status() -> None:
    """Activate or deactivate a stored fellowship contact."""

    print()

    contact_id_input = input(
        "Contact ID: "
    ).strip()

    if not contact_id_input.isdigit():
        print(
            "Please enter a valid contact ID."
        )
        print()
        return

    active_input = input(
        "Set active? (y/n): "
    ).strip().lower()

    if active_input not in {
        "y",
        "n",
    }:
        print(
            "Please enter y or n."
        )
        print()
        return

    contact = set_contact_active(
        contact_id=int(
            contact_id_input
        ),
        active=(
            active_input == "y"
        ),
    )

    if contact is None:
        print("Contact not found.")

    else:
        status = (
            "active"
            if contact["active"]
            else "inactive"
        )

        print(
            f"{contact['handle']} "
            f"is now {status}."
        )

    print()


def who_should_i_call() -> None:
    """Recommend up to three active human contacts."""

    print()
    print("Who Should I Call?")
    print("=" * 50)

    contacts = recommend_contacts(
        contacts=load_contacts(),
        limit=3,
    )

    if not contacts:
        print(
            "No active fellowship contacts are available."
        )
        print()
        return

    print(
        "Recommended contacts:"
    )
    print()

    for index, contact in enumerate(
        contacts,
        start=1,
    ):
        print(
            f"{index}. {contact['handle']} "
            f"({contact['contact_type']})"
        )

        if contact.get(
            "contact_method"
        ):
            print(
                f"   Contact: "
                f"{contact['contact_method']}"
            )

        if contact.get(
            "notes"
        ):
            print(
                f"   Notes: "
                f"{contact['notes']}"
            )

    print()


def run_fellowship_menu() -> None:
    """Run the Fellowship submenu."""

    run_menu(
        "Fellowship",
        [
            (
                "View Contacts",
                view_fellowship_contacts,
            ),
            (
                "Add Contact",
                create_fellowship_contact,
            ),
            (
                "Change Contact Status",
                change_fellowship_contact_status,
            ),
            (
                "Who Should I Call?",
                who_should_i_call,
            ),
        ],
    )


# ============================================================
# Daily Recovery
# ============================================================

def run_daily_checkin() -> None:
    """Create or update today's Daily Recovery Check-In."""

    print()
    print("Daily Check-In")
    print("=" * 50)

    prompts = [
        (
            "prayer_meditation",
            "Prayer / meditation",
        ),
        (
            "recovery_contact",
            "Recovery contact",
        ),
        (
            "meeting",
            "Meeting",
        ),
        (
            "step_work",
            "Step work",
        ),
        (
            "journal",
            "Journal",
        ),
        (
            "service",
            "Service",
        ),
    ]

    values: dict[str, bool] = {}

    for field, label in prompts:
        response = input(
            f"{label} completed today? (y/n): "
        ).strip().lower()

        values[field] = (
            response == "y"
        )

    print()

    note = input(
        "Daily note (optional): "
    ).strip()

    checkin = save_daily_checkin(
        values=values,
        note=note,
    )

    print()
    print(
        "Daily check-in saved."
    )
    print()
    print(
        format_checkin(
            checkin
        )
    )
    print()


def view_today_checkin() -> None:
    """Display today's saved check-in."""

    print()

    print(
        format_checkin(
            get_checkin_for_date(
                date.today().isoformat()
            )
        )
    )

    print()


def view_checkin_history() -> None:
    """Display the seven most recent check-ins."""

    print()
    print("Recent Check-In History")
    print("=" * 50)

    checkins = get_recent_checkins(
        limit=7
    )

    print(
        format_checkin_history(
            checkins
        )
    )

    print()


def view_checkin_trends() -> None:
    """Display deterministic trends from recent check-ins."""

    print()
    print("Check-In Trends")
    print("=" * 50)

    checkins = get_recent_checkins(
        limit=7
    )

    print(
        format_checkin_trends(
            checkins
        )
    )

    print()


def analyze_recent_checkins() -> None:
    """Explicitly send recent check-in summaries to the AI."""

    print()
    print("Analyze Recent Check-Ins")
    print("=" * 50)

    checkins = get_recent_checkins(
        limit=7
    )

    if not checkins:
        print(
            "No recent check-ins available."
        )
        print()
        return

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

    print(
        checkin_text
    )
    print()

    print(
        "Only the recent check-in summary shown above "
        "will be sent to the AI."
    )

    confirm = input(
        "Analyze these check-ins? (y/n): "
    ).strip().lower()

    if confirm != "y":
        print(
            "Analysis cancelled."
        )
        print()
        return

    print()
    print(
        "Recovery Companion Check-In Analysis:"
    )

    print(
        analyze_checkin_trends(
            checkin_text
        )
    )

    print()


def run_daily_recovery_menu() -> None:
    """Run Daily Check-In, history, trends, and analysis tools."""

    run_menu(
        "Daily Recovery",
        [
            (
                "Daily Check-In",
                run_daily_checkin,
            ),
            (
                "View Today's Check-In",
                view_today_checkin,
            ),
            (
                "Check-In History",
                view_checkin_history,
            ),
            (
                "Check-In Trends",
                view_checkin_trends,
            ),
            (
                "Analyze Recent Check-Ins",
                analyze_recent_checkins,
            ),
        ],
    )


# ============================================================
# Weekly Recovery Review
# ============================================================

def view_weekly_review() -> None:
    """Build and display the current deterministic weekly review."""

    print()
    print(
        build_weekly_review()
    )
    print()


def analyze_weekly_recovery_review() -> None:
    """Explicitly send the current weekly review to the AI."""

    print()
    print("Analyze Weekly Recovery Review")
    print("=" * 50)

    weekly_review_text = build_weekly_review()

    print(
        weekly_review_text
    )
    print()

    print(
        "Only the weekly recovery summary shown above "
        "will be sent to the AI."
    )

    confirm = input(
        "Analyze this weekly review? (y/n): "
    ).strip().lower()

    if confirm != "y":
        print(
            "Analysis cancelled."
        )
        print()
        return

    print()
    print(
        "Recovery Companion Weekly Review Analysis:"
    )

    print(
        analyze_weekly_review(
            weekly_review_text
        )
    )

    print()


def save_current_weekly_review() -> None:
    """Save or replace the current week's local snapshot."""

    print()
    print("Save Weekly Recovery Review")
    print("=" * 50)

    snapshot = save_weekly_review_snapshot()

    print(
        "Saved weekly review: "
        f"{snapshot['week_start']} "
        f"to {snapshot['week_end']}"
    )

    print()


def view_weekly_review_history() -> None:
    """Display previously saved weekly snapshots."""

    print()

    print(
        format_weekly_review_history(
            load_weekly_review_history()
        )
    )

    print()


def compare_weekly_reviews() -> None:
    """Compare the two most recently saved weekly snapshots."""

    print()

    print(
        compare_latest_weekly_reviews(
            load_weekly_review_history()
        )
    )

    print()


def analyze_saved_weekly_comparison() -> None:
    """Explicitly send the latest saved weekly comparison to AI."""

    print()
    print("Analyze Weekly Review Comparison")
    print("=" * 50)

    history = load_weekly_review_history()

    if len(history) < 2:
        print(
            "At least two saved weekly reviews are needed "
            "for AI comparison."
        )
        print()
        return

    comparison_text = compare_latest_weekly_reviews(
        history
    )

    print(
        comparison_text
    )
    print()

    print(
        "Only the weekly comparison shown above "
        "will be sent to the AI."
    )

    confirm = input(
        "Analyze this weekly comparison? (y/n): "
    ).strip().lower()

    if confirm != "y":
        print(
            "Analysis cancelled."
        )
        print()
        return

    print()
    print(
        "Recovery Companion Weekly Comparison Analysis:"
    )

    print(
        analyze_weekly_comparison(
            comparison_text
        )
    )

    print()


# ============================================================
# Monthly Recovery Review
# ============================================================

def view_monthly_review() -> None:
    """Display the rolling four-week Monthly Recovery Review."""

    print()
    print(
        build_monthly_review()
    )
    print()


def analyze_monthly_recovery_review() -> None:
    """Explicitly send the rolling four-week review to the AI."""

    print()
    print("Analyze Monthly Recovery Review")
    print("=" * 50)

    monthly_review_text = build_monthly_review()

    print(
        monthly_review_text
    )
    print()

    if (
        "No saved weekly reviews are available yet."
        in monthly_review_text
    ):
        return

    print(
        "Only the monthly recovery summary shown above "
        "will be sent to the AI."
    )

    confirm = input(
        "Analyze this monthly review? (y/n): "
    ).strip().lower()

    if confirm != "y":
        print(
            "Analysis cancelled."
        )
        print()
        return

    print()
    print(
        "Recovery Companion Monthly Review Analysis:"
    )

    print(
        analyze_monthly_review(
            monthly_review_text
        )
    )

    print()


def save_current_monthly_review() -> None:
    """Save the current rolling four-week Monthly Recovery Review."""

    print()
    print("Save Monthly Recovery Review")
    print("=" * 50)

    try:
        snapshot = save_monthly_review_snapshot()

    except ValueError as error:
        print(error)
        print()
        return

    print(
        "Saved monthly review snapshot: "
        f"{snapshot['snapshot_date']}"
    )

    print(
        f"Period: {snapshot['period_start']} "
        f"to {snapshot['period_end']}"
    )

    print()


def view_monthly_review_history() -> None:
    """Display saved Monthly Recovery Review snapshots."""

    print()

    print(
        format_monthly_review_history(
            load_monthly_review_history()
        )
    )

    print()


def compare_monthly_reviews() -> None:
    """Compare the two most recent saved monthly snapshots."""

    print()

    print(
        compare_latest_monthly_reviews(
            load_monthly_review_history()
        )
    )

    print()

def analyze_saved_monthly_comparison() -> None:
    """Explicitly send the latest saved monthly comparison to the AI."""

    print()
    print("Analyze Monthly Review Comparison")
    print("=" * 50)

    history = load_monthly_review_history()

    if len(history) < 2:
        print(
            "At least two saved monthly reviews are needed "
            "for AI comparison."
        )
        print()
        return

    comparison_text = compare_latest_monthly_reviews(
        history
    )

    print(
        comparison_text
    )
    print()

    print(
        "Only the monthly comparison shown above "
        "will be sent to the AI."
    )

    confirm = input(
        "Analyze this monthly comparison? (y/n): "
    ).strip().lower()

    if confirm != "y":
        print("Analysis cancelled.")
        print()
        return

    print()
    print(
        "Recovery Companion Monthly Comparison Analysis:"
    )

    print(
        analyze_monthly_comparison(
            comparison_text
        )
    )

    print()

# ============================================================
# Reviews & Trends
# ============================================================

def run_reviews_menu() -> None:
    """
    Run weekly and monthly recovery-review tools.

    All longitudinal review features live here so the main menu
    remains small even as new review capabilities are added.
    """

    run_menu(
        "Reviews & Trends",
        [
            (
                "Weekly Recovery Review",
                view_weekly_review,
            ),
            (
                "Analyze Weekly Recovery Review",
                analyze_weekly_recovery_review,
            ),
            (
                "Save Weekly Recovery Review",
                save_current_weekly_review,
            ),
            (
                "Weekly Review History",
                view_weekly_review_history,
            ),
            (
                "Compare Weekly Reviews",
                compare_weekly_reviews,
            ),
            (
                "Analyze Weekly Comparison",
                analyze_saved_weekly_comparison,
            ),
            (
                "Monthly Recovery Review",
                view_monthly_review,
            ),
            (
                "Analyze Monthly Recovery Review",
                analyze_monthly_recovery_review,
            ),
            (
                "Save Monthly Recovery Review",
                save_current_monthly_review,
            ),
            (
                "Monthly Review History",
                view_monthly_review_history,
            ),
            (
                "Compare Monthly Reviews",
                compare_monthly_reviews,
            ),
            (
                "Analyze Monthly Comparison",
                analyze_saved_monthly_comparison,
            ),
        ],
    )


# ============================================================
# Dashboard and Settings
# ============================================================

def view_dashboard() -> None:
    """Display the Daily Recovery Dashboard."""

    print()
    print(
        build_dashboard()
    )
    print()

def view_recovery_insights() -> None:
    """Display the deterministic longitudinal Recovery Insights dashboard."""

    print()
    print(
        build_recovery_insights()
    )
    print()

def analyze_recovery_insights_dashboard() -> None:
    """Explicitly send the Recovery Insights summary to the AI."""

    print()
    print("Analyze Recovery Insights")
    print("=" * 50)

    insights_text = build_recovery_insights()

    print(insights_text)
    print()

    print(
        "Only the Recovery Insights summary shown above "
        "will be sent to the AI."
    )

    confirm = input(
        "Analyze these recovery insights? (y/n): "
    ).strip().lower()

    if confirm != "y":
        print("Analysis cancelled.")
        print()
        return

    print()
    print("Recovery Companion Insights Analysis:")

    print(
        analyze_recovery_insights(
            insights_text
        )
    )

    print()

def change_sobriety_date() -> None:
    """Validate and save the user's sobriety date."""

    print()
    print("Set Sobriety Date")
    print("=" * 50)

    sobriety_date_input = input(
        "Sobriety date (YYYY-MM-DD): "
    ).strip()

    try:
        sobriety_date = date.fromisoformat(
            sobriety_date_input
        )

    except ValueError:
        print(
            "Please enter a valid date "
            "in YYYY-MM-DD format."
        )
        print()
        return

    if sobriety_date > date.today():
        print(
            "Sobriety date cannot be in the future."
        )
        print()
        return

    set_sobriety_date(
        sobriety_date.isoformat()
    )

    print(
        "Sobriety date set to "
        f"{sobriety_date.isoformat()}."
    )

    print()


def run_settings_menu() -> None:
    """Run Recovery Companion settings."""

    run_menu(
        "Settings",
        [
            (
                "Set Sobriety Date",
                change_sobriety_date,
            ),
        ],
    )

# ============================================================
# Goals & Commitments
# ============================================================

def view_goals() -> None:
    """Display all saved recovery goals."""

    print()
    print("Recovery Goals")
    print("=" * 50)
    print(
        format_goals(
            load_goals()
        )
    )
    print()


def view_active_goals() -> None:
    """Display active recovery goals only."""

    print()
    print("Active Recovery Goals")
    print("=" * 50)
    print(
        format_goals(
            get_active_goals()
        )
    )
    print()


def create_goal() -> None:
    """Create a new recovery goal."""

    print()
    print("Add Recovery Goal")
    print("=" * 50)

    text = input(
        "Goal: "
    ).strip()

    area = input(
        "Area "
        "(connection, step_work, meetings, prayer, "
        "journal, service, health, other): "
    ).strip()

    target_date = input(
        "Target date (YYYY-MM-DD, optional): "
    ).strip()

    try:
        goal = add_goal(
            text=text,
            area=area,
            target_date=target_date,
        )
    except ValueError as error:
        print(error)
        print()
        return

    print()
    print(
        f"Goal {goal['id']} saved."
    )
    print()


def mark_goal_complete() -> None:
    """Mark a saved goal complete."""

    print()

    goal_id_input = input(
        "Goal ID: "
    ).strip()

    if not goal_id_input.isdigit():
        print(
            "Please enter a valid goal ID."
        )
        print()
        return

    goal = complete_goal(
        int(goal_id_input)
    )

    if goal is None:
        print("Goal not found.")
    else:
        print(
            f"Goal {goal['id']} marked complete."
        )

    print()


def reactivate_saved_goal() -> None:
    """Return a completed goal to active status."""

    print()

    goal_id_input = input(
        "Goal ID: "
    ).strip()

    if not goal_id_input.isdigit():
        print(
            "Please enter a valid goal ID."
        )
        print()
        return

    goal = reactivate_goal(
        int(goal_id_input)
    )

    if goal is None:
        print("Goal not found.")
    else:
        print(
            f"Goal {goal['id']} reactivated."
        )

    print()


def run_goals_menu() -> None:
    """Run the Goals & Commitments submenu."""

    run_menu(
        "Goals & Commitments",
        [
            (
                "View All Goals",
                view_goals,
            ),
            (
                "View Active Goals",
                view_active_goals,
            ),
            (
                "Add Goal",
                create_goal,
            ),
            (
                "Mark Goal Complete",
                mark_goal_complete,
            ),
            (
                "Reactivate Goal",
                reactivate_saved_goal,
            ),
        ],
    )

# ============================================================
# Main menu
# ============================================================

def main() -> None:
    """
    Start Recovery Companion.

    The main menu intentionally stays small. Detailed features live
    inside domain-specific submenus.
    """

    print()
    print("=" * 50)
    print(
        f"Recovery Companion v{__version__}"
    )
    print("=" * 50)

    run_menu(
        "Main Menu",
        [
            (
                "Dashboard",
                view_dashboard,
            ),
            (
                "Recovery Insights",
                view_recovery_insights,
            ),
            (
                "Analyze Recovery Insights",
                analyze_recovery_insights_dashboard,
            ),
            (
                "Daily Recovery",
                run_daily_recovery_menu,
            ),
            (
                "Reviews & Trends",
                run_reviews_menu,
            ),
            (
                "Journal",
                run_journal_menu,
            ),
            (
                "Step Work",
                run_step_work_menu,
            ),
            (
                "Fellowship",
                run_fellowship_menu,
            ),
            (
                "Chat",
                run_chat,
            ),
            (
                "Settings",
                run_settings_menu,
            ),
            (
                "Goals & Commitments",
                run_goals_menu,
            ),
        ],
        final_label="Exit",
    )

    print()
    print(
        "Recovery Companion: "
        "Take care. Keep coming back."
    )


# Only start the CLI when this file is executed directly.
# Importing main.py from tests or another module will not launch it.
if __name__ == "__main__":
    main()