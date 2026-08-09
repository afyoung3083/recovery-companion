from app.journal import (
    add_entry,
    filter_entries_by_tag,
    format_entries,
    load_entries,
    search_entries,
)
from app.recovery_engine import (
    analyze_journal_entry,
    analyze_step_work,
    respond_to_user,
)
from app.step_work import (
    add_assignment,
    add_step_note,
    complete_assignment,
    format_step_work,
    load_step_work,
    set_current_step,
)
from app.fellowship import (
    add_contact,
    format_contacts,
    load_contacts,
    recommend_contacts,
    set_contact_active,
)
from app.daily_checkin import(
    format_checkin,
    get_checkin_for_date,
    save_daily_checkin,
)
from app.daily_checkin import (
    format_checkin,
    format_checkin_history,
    format_checkin_trends,
    get_checkin_for_date,
    get_recent_checkins,
    save_daily_checkin,
)
from app.dashboard import build_dashboard
from datetime import date
from app.profile import set_sobriety_date

def run_chat() -> None:
    conversation: list[dict[str, str]] = []

    print()
    print("Recovery Companion Chat")
    print("Type 'back' to return to the main menu.")
    print()

    while True:
        user_message = input("You: ").strip()

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
            response = respond_to_user(conversation)
        except Exception as error:
            print()
            print(f"Error: {error}")
            print()
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


def write_journal_entry() -> None:
    print()
    print("New Journal Entry")
    print("Enter your journal entry on one line.")
    print()

    text = input("Journal: ").strip()

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
    print(f"Journal entry {entry['id']} saved.")
    print()


def view_journal() -> None:
    print()
    print("Journal Entries")
    print("=" * 50)
    print(format_entries(load_entries()))
    print()


def search_journal() -> None:
    print()
    print("Search Journal")
    print("=" * 50)

    query = input("Search term or tag: ").strip()

    if not query:
        print("No search term entered.")
        print()
        return

    matches = search_entries(
        entries=load_entries(),
        query=query,
    )

    print()
    print(format_entries(matches))
    print()


def filter_journal_by_tag() -> None:
    print()
    print("Filter Journal by Tag")
    print("=" * 50)

    tag = input("Tag: ").strip()

    if not tag:
        print("No tag entered.")
        print()
        return

    matches = filter_entries_by_tag(
        entries=load_entries(),
        tag=tag,
    )

    print()
    print(format_entries(matches))
    print()


def analyze_journal() -> None:
    print()
    print("Analyze Journal Entry")
    print("=" * 50)

    entries = load_entries()

    if not entries:
        print("No journal entries available.")
        print()
        return

    print(format_entries(entries))
    print()

    entry_id_input = input("Entry ID to analyze: ").strip()

    if not entry_id_input.isdigit():
        print("Please enter a valid journal entry ID.")
        print()
        return

    entry_id = int(entry_id_input)

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
    print("Only this selected entry will be sent to the AI.")

    confirm = input(
        "Analyze this entry? (y/n): "
    ).strip().lower()

    if confirm != "y":
        print("Analysis cancelled.")
        print()
        return

    print()
    print("Recovery Companion Journal Analysis:")
    print(
        analyze_journal_entry(
            selected_entry.get("text", "")
        )
    )
    print()


def view_step_work() -> None:
    print()
    print("Step Work")
    print("=" * 50)
    print(format_step_work(load_step_work()))
    print()


def change_current_step() -> None:
    print()

    step_input = input(
        "Current Step (1-12): "
    ).strip()

    if not step_input.isdigit():
        print("Please enter a number from 1 to 12.")
        print()
        return

    step_number = int(step_input)

    try:
        set_current_step(step_number)
    except ValueError as error:
        print(error)
        print()
        return

    print(f"Current Step set to {step_number}.")
    print()


def create_step_assignment() -> None:
    print()

    text = input("Assignment: ").strip()

    if not text:
        print("Assignment was not saved.")
        print()
        return

    assignment = add_assignment(text)

    print(
        f"Assignment {assignment['id']} added "
        f"to Step {assignment['step']}."
    )
    print()


def mark_step_assignment_complete() -> None:
    print()

    assignment_input = input(
        "Assignment ID: "
    ).strip()

    if not assignment_input.isdigit():
        print("Please enter a valid assignment ID.")
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
    print()

    text = input("Step note: ").strip()

    if not text:
        print("Note was not saved.")
        print()
        return

    note = add_step_note(text)

    print(
        f"Note {note['id']} added "
        f"to Step {note['step']}."
    )
    print()


def analyze_current_step_work() -> None:
    print()
    print("Analyze Current Step Work")
    print("=" * 50)

    step_work = load_step_work()
    step_work_text = format_step_work(step_work)

    print(step_work_text)
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
    print("Recovery Companion Step Work Analysis:")
    print(analyze_step_work(step_work_text))
    print()


def run_step_work_menu() -> None:
    while True:
        print()
        print("Step Work")
        print("=" * 50)
        print("1. View Step Work")
        print("2. Change Current Step")
        print("3. Add Assignment")
        print("4. Mark Assignment Complete")
        print("5. Add Step Note")
        print("6. Analyze Current Step Work")
        print("7. Back")
        print()

        choice = input(
            "Choose an option: "
        ).strip()

        if choice == "1":
            view_step_work()
        elif choice == "2":
            change_current_step()
        elif choice == "3":
            create_step_assignment()
        elif choice == "4":
            mark_step_assignment_complete()
        elif choice == "5":
            create_step_note()
        elif choice == "6":
            analyze_current_step_work()
        elif choice == "7":
            return
        else:
            print(
                "Please choose 1, 2, 3, 4, 5, 6, or 7."
            )

def view_fellowship_contacts() -> None:
    print()
    print("Fellowship Contacts")
    print("=" * 50)
    print(format_contacts(load_contacts()))
    print()


def create_fellowship_contact() -> None:
    print()
    print("Add Fellowship Contact")
    print("=" * 50)

    handle = input("Handle or name: ").strip()

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
        f"{contact['handle']} ({contact['contact_type']})."
    )
    print()


def change_fellowship_contact_status() -> None:
    print()

    contact_id_input = input(
        "Contact ID: "
    ).strip()

    if not contact_id_input.isdigit():
        print("Please enter a valid contact ID.")
        print()
        return

    active_input = input(
        "Set active? (y/n): "
    ).strip().lower()

    if active_input not in {"y", "n"}:
        print("Please enter y or n.")
        print()
        return

    contact = set_contact_active(
        contact_id=int(contact_id_input),
        active=(active_input == "y"),
    )

    if contact is None:
        print("Contact not found.")
    else:
        status = "active" if contact["active"] else "inactive"
        print(
            f"{contact['handle']} is now {status}."
        )

    print()

def who_should_i_call() -> None:
    print()
    print("Who Should I Call?")
    print("=" * 50)

    contacts = recommend_contacts(
        contacts=load_contacts(),
        limit=3,
    )

    if not contacts:
        print("No active fellowship contacts are available.")
        print()
        return

    print("Recommended contacts:")
    print()

    for index, contact in enumerate(contacts, start=1):
        print(
            f"{index}. {contact['handle']} "
            f"({contact['contact_type']})"
        )

        if contact.get("contact_method"):
            print(
                f"   Contact: {contact['contact_method']}"
            )

        if contact.get("notes"):
            print(
                f"   Notes: {contact['notes']}"
            )

    print()

def view_dashboard() -> None:
    print()
    print(build_dashboard())
    print()    

def run_fellowship_menu() -> None:
    while True:
        print()
        print("Fellowship")
        print("=" * 50)
        print("1. View Contacts")
        print("2. Add Contact")
        print("3. Change Contact Status")
        print("4. Who Should I Call?")
        print("5. Back")
        print()

        choice = input("Choose an option: ").strip()

        if choice == "1":
            view_fellowship_contacts()
        elif choice == "2":
            create_fellowship_contact()
        elif choice == "3":
            change_fellowship_contact_status()
        elif choice == "4":
            who_should_i_call()
        elif choice == "5":
            return
        else:
            print("Please choose 1, 2, 3, 4, or 5.")

def change_sobriety_date() -> None:
    print()
    print("Set Sobriety Date")
    print("=" * 50)

    sobriety_date_input = input(
        "Sobriety date (YYYY-MM-DD): "
    ).strip()

    try:
        sobriety_date = date.fromisoformat(sobriety_date_input)
    except ValueError:
        print("Please enter a valid date in YYYY-MM-DD format.")
        print()
        return

    if sobriety_date > date.today():
        print("Sobriety date cannot be in the future.")
        print()
        return

    set_sobriety_date(sobriety_date.isoformat())

    print(
        f"Sobriety date set to {sobriety_date.isoformat()}."
    )
    print()

def run_daily_checkin() -> None:
    print()
    print("Daily Check-In")
    print("=" * 50)

    prompts = [
        ("prayer_meditation", "Prayer / meditation"),
        ("recovery_contact", "Recovery contact"),
        ("meeting", "Meeting"),
        ("step_work", "Step work"),
        ("journal", "Journal"),
        ("service", "Service"),
    ]

    values: dict[str, bool] = {}

    for field, label in prompts:
        response = input(
            f"{label} completed today? (y/n): "
        ).strip().lower()

        values[field] = response == "y"

    print()
    note = input(
        "Daily note (optional): "
    ).strip()

    checkin = save_daily_checkin(
        values=values,
        note=note,
    )

    print()
    print("Daily check-in saved.")
    print()
    print(format_checkin(checkin))
    print()


def view_today_checkin() -> None:
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
    print()
    print("Recent Check-In History")
    print("=" * 50)

    checkins = get_recent_checkins(limit=7)

    print(format_checkin_history(checkins))
    print()


def view_checkin_trends() -> None:
    print()
    print("Check-In Trends")
    print("=" * 50)

    checkins = get_recent_checkins(limit=7)

    print(format_checkin_trends(checkins))
    print()

def main() -> None:
    print("=" * 50)
    print("Recovery Companion v0.11")
    print("=" * 50)

    while True:
        print()
        print("1. Dashboard")
        print("2. Daily Check-In")
        print("3. View Today's Check-In")
        print("4. Check-In History")
        print("5. Check-In Trends")
        print("6. Set Sobriety Date")
        print("7. Chat")
        print("8. Write Journal Entry")
        print("9. View Journal")
        print("10. Search Journal")
        print("11. Filter Journal by Tag")
        print("12. Analyze Journal Entry")
        print("13. Step Work")
        print("14. Fellowship")
        print("15. Exit")
        print()

        choice = input(
            "Choose an option: "
        ).strip()

        if choice == "1":
            view_dashboard()
        elif choice == "2":
            run_daily_checkin()
        elif choice == "3":
            view_today_checkin()
        elif choice == "4":
            view_checkin_history()
        elif choice == "5":
            view_checkin_trends()
        elif choice == "6":
            change_sobriety_date()
        elif choice == "7":
            run_chat()
        elif choice == "8":
            write_journal_entry()
        elif choice == "9":
            view_journal()
        elif choice == "10":
            search_journal()
        elif choice == "11":
            filter_journal_by_tag()
        elif choice == "12":
            analyze_journal()
        elif choice == "13":
            run_step_work_menu()
        elif choice == "14":
            run_fellowship_menu()
        elif choice == "15":
            print("Recovery Companion: Take care. Keep coming back.")
            break
        else:
            print("Please choose 1 through 15.")


if __name__ == "__main__":
    main()