from app.journal import add_entry, format_entries, load_entries
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

    entry = add_entry(text)

    print()
    print(f"Journal entry {entry['id']} saved.")
    print()


def view_journal() -> None:
    print()
    print("Journal Entries")
    print("=" * 50)
    print(format_entries(load_entries()))
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
        print("4. Exit")
        print()

        choice = input("Choose an option: ").strip()

        if choice == "1":
            run_chat()
        elif choice == "2":
            write_journal_entry()
        elif choice == "3":
            view_journal()
        elif choice == "4":
            print("Recovery Companion: Take care. Keep coming back.")
            break
        else:
            print("Please choose 1, 2, 3, or 4.")


if __name__ == "__main__":
    main()