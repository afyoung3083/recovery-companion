from app.recovery_engine import respond_to_user


def main() -> None:
    print("=" * 50)
    print("Recovery Companion v0.1")
    print("=" * 50)
    print()

    user_message = input("You: ").strip()

    if not user_message:
        print("Please enter a message.")
        return

    try:
        response = respond_to_user(user_message)
    except Exception as error:
        print()
        print(f"Error: {error}")
        return

    print()
    print("Recovery Companion:")
    print(response)


if __name__ == "__main__":
    main()