"""Audit source-level Data Safety assumptions.

This script does not attempt to prove cloud-provider configuration.
It protects source-level contracts that can be established from this
repository.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

AI_CLIENT = ROOT / "app" / "ai_client.py"
CONFIG = ROOT / "app" / "config.py"
API = ROOT / "app" / "api.py"
ENGINE = ROOT / "app" / "recovery_engine.py"


def require(
    condition: bool,
    message: str,
) -> None:
    if not condition:
        raise SystemExit(message)


ai_client = AI_CLIENT.read_text(
    encoding="utf-8"
)

config = CONFIG.read_text(
    encoding="utf-8"
)

api = API.read_text(
    encoding="utf-8"
)

engine = ENGINE.read_text(
    encoding="utf-8"
)

require(
    "responses.create(" in ai_client,
    "OpenAI Responses API call not found.",
)

require(
    "store=False" in ai_client,
    "AI requests must explicitly use store=False.",
)

require(
    "OPENAI_API_KEY" in config,
    "OpenAI provider configuration not found.",
)

require(
    "respond_to_user" in engine,
    "Recovery Companion chat AI path not found.",
)

require(
    "analyze_journal_entry" in engine,
    "Journal AI path not found.",
)

require(
    "analyze_checkin_trends" in engine,
    "Daily Recovery AI path not found.",
)

require(
    "analyze_recovery_insights" in engine,
    "Recovery Insights AI path not found.",
)

require(
    "analyze_weekly_review" in engine,
    "Weekly Review AI path not found.",
)

require(
    "analyze_monthly_review" in engine,
    "Monthly Review AI path not found.",
)

# FastAPI request models confirm that online AI routes receive user
# supplied text/summary data.
for request_model in (
    "ChatRequest",
    "AiReflectionSummaryRequest",
    "RecoveryInsightsAiRequest",
    "WeeklyReviewAiRequest",
    "MonthlyReviewAiRequest",
):
    require(
        request_model in api,
        f"Expected AI request model missing: {request_model}",
    )

# These are simplistic but intentional tripwires. A future developer
# who adds explicit logging to application-level request handling must
# reassess the Data Safety evidence rather than silently changing it.
for logging_token in (
    "logger.info(request",
    "logger.debug(request",
    "logging.info(request",
    "logging.debug(request",
):
    require(
        logging_token not in api,
        "Potential request logging detected; "
        "reassess Data Safety documentation.",
    )

print(
    "Data Safety source audit passed."
)
print(
    "Verified: AI uses Responses API with store=False."
)
print(
    "Verified: user-facing AI paths route through recovery_engine."
)
print(
    "Verified: no known application-level request-body logging "
    "tripwire was detected."
)
print(
    "Not verified by source: provider retention, cloud access logs, "
    "ZDR eligibility, contractual sharing treatment, or production TLS."
)
