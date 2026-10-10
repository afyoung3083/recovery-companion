"""Explicit entry point; default execution is an offline plan, not a paid run."""
from evals.conversation_comparison import main

if __name__ == "__main__":
    raise SystemExit(main())
