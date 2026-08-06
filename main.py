from app.recovery_engine import respond_to_user


def main() -> None:
    print("=" * 50)
    print("Recovery Companion v0.2")
    print("=" * 50)
    print("Type 'exit' to end the conversation.")
    print()

    conversation: list[dict[str, str]] = []

    while True:
        user_message = input("You: ").strip()

        if user_message.lower() in {"exit", "quit"}:
            print("Recovery Companion: Take care. Keep coming back.")
            break

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


if __name__ == "__main__":
    main()