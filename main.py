from app.journal import (
    add_entry,
    filter_entries_by_tag,
    format_entries,
    load_entries,
    search_entries,
)
from app.recovery_engine import respond_to_user


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

def main() -> None:
    print("=" * 50)
    print("Recovery Companion v0.3")
    print("=" * 50)

    while True:
        print()
        print("1. Chat")
        print("2. Write Journal Entry")
        print("3. View Journal")
        print("4. Search Journal")
        print("5. Filter Journal by Tag")
        print("6. Exit")
        print()

        choice = input("Choose an option: ").strip()

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
            print("Recovery Companion: Take care. Keep coming back.")
            break
        else:
            print("Please choose 1, 2, 3, 4, 5, or 6.")


if __name__ == "__main__":
    main()