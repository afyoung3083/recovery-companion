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


def main() -> None:
    print("=" * 50)
    print("Recovery Companion v0.6")
    print("=" * 50)

    while True:
        print()
        print("1. Chat")
        print("2. Write Journal Entry")
        print("3. View Journal")
        print("4. Search Journal")
        print("5. Filter Journal by Tag")
        print("6. Analyze Journal Entry")
        print("7. Step Work")
        print("8. Exit")
        print()

        choice = input(
            "Choose an option: "
        ).strip()

        if choice == "1":
            run_chat()
        elif choice == "2":
            write_journal_entry()
        elif choice == "3":
            view_journal()
        elif choice == "4":
            search_journal()
        elif choice == "5":
            filter_journal_by_tag()
        elif choice == "6":
            analyze_journal()
        elif choice == "7":
            run_step_work_menu()
        elif choice == "8":
            print(
                "Recovery Companion: "
                "Take care. Keep coming back."
            )
            break
        else:
            print(
                "Please choose 1, 2, 3, 4, "
                "5, 6, 7, or 8."
            )


if __name__ == "__main__":
    main()