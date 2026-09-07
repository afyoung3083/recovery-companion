from app.ai_client import generate_response
from app.config import PROMPT_FILE


# ============================================================
# Core chat behavior
# ============================================================

def load_system_prompt() -> str:
    """Load the primary Recovery Companion system prompt."""

    if not PROMPT_FILE.exists():
        raise FileNotFoundError(
            f"Prompt file not found: {PROMPT_FILE}"
        )

    return PROMPT_FILE.read_text(
        encoding="utf-8"
    ).strip()


def respond_to_user(
    conversation: list[dict[str, str]],
) -> str:
    """
    Generate a normal Recovery Companion chat response.

    Normal chat uses the external Recovery Companion system prompt
    stored in the configured prompt file.

    Ordinary Chat requests low reasoning effort and low text verbosity
    to reduce response-generation latency. Specialized AI reflections
    are unaffected and keep the model's default settings.
    """

    system_prompt = load_system_prompt()

    return generate_response(
        conversation=conversation,
        instructions=system_prompt,
        reasoning_effort="low",
        verbosity="low",
    )


# ============================================================
# Journal intelligence
# ============================================================

_SPECIALIZED_REFLECTION_PROMPT = """
You are writing a concise reflection for a Twelve-Step recovery companion.

The user explicitly chose to share the supplied material for reflection.

Use exactly these two sections and no other section headings:

Observations

Optional suggestions

Requirements:

- Keep the entire response concise, usually about 80 to 150 words.
- Under "Observations", write approximately 3 to 4 concise sentences,
    preferably as one short paragraph.
- State direct observations from the supplied material first.
- Keep facts separate from inference. Do not force an interpretation for every fact;
    neutral activities may remain neutral.
- Do not assign recovery meaning to ordinary neutral events or their sequence.
    Weather, chores, timing coincidences, inconveniences, and outcomes outside
    the user's control must remain descriptive unless the user explicitly gives
    them emotional or recovery significance.
- Do not introduce themes such as control, acceptance, surrender, letting go,
    expectations, perfectionism, compulsivity, or restlessness merely because an
    ordinary action was followed by an uncontrollable event.
- Do not invent motives, causes, fears, character tendencies, recurring
    patterns, or spiritual meaning from isolated events or missing context.
- When an inference is genuinely useful and supported by the material, phrase them tentatively
    with words such as "may", "might", "could", "possibly",
    "seems", or "worth noticing".
- Do not diagnose, state a character defect as fact, infer spiritual condition,
    or treat activity counts as recovery scores.
- Do not imply that high activity proves good recovery or that low activity,
    missed actions, or missing data prove poor recovery, worsening recovery, or
    relapse.
- Under "Optional suggestions", provide zero to three short bullets only when
    useful. Every suggestion must clearly be optional, beginning with wording
    such as "If useful, you might...", "You could consider...", or "If it feels
    relevant...".
- Optional suggestions must not introduce a psychological, spiritual, or
    recovery interpretation that was not already supported in Observations.
- Suggestions are not assignments, requirements, or conditions of sobriety.
    Do not imply that the user must complete them or that relapse risk depends
    on following them.
- Suggest human connection, Higher Power, or Step Work only when genuinely
    relevant to the supplied material. Do not recommend contacting a sponsor in
    every reflection.
- Preserve appropriate human recovery support and do not replace a sponsor,
    fellowship, therapist, clergy member, or Higher Power.

Analyze only the supplied material.
"""

def analyze_journal_entry(
    entry_text: str,
) -> str:
    """
    Analyze one explicitly selected journal entry.

    The analysis emphasizes tentative interpretation, recovery
    strengths, human connection, and practical next-right actions.
    """

    conversation = [
        {
            "role": "user",
            "content": entry_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=_SPECIALIZED_REFLECTION_PROMPT,
    )


# ============================================================
# Step Work intelligence
# ============================================================

def analyze_step_work(
    step_work_text: str,
) -> str:
    """
    Analyze current Step Work without controlling Step progression.

    Significant Step decisions remain with the user, sponsor,
    and fellowship rather than the AI.
    """

    step_prompt = """
You are helping with Twelve-Step recovery Step work.

The user explicitly chose to share their current Step work.

Your role is to support, not replace, the user's sponsor or fellowship.

Structure your response using exactly these sections:

Current Step theme

Progress already visible

Possible areas to explore

Next-right actions

Requirements:

- Use the exact section headings shown above.
- Always include the "Next-right actions" heading.
- Under "Current Step theme", identify the current recovery theme or
  Step principle without declaring the Step complete.
- Under "Progress already visible", reflect only progress supported by
  the supplied Step Work.
- Under "Possible areas to explore", use tentative language such as
  "may", "might", "could", "possibly", or "worth exploring" for any
  inferred pattern, motive, fear, or character tendency.
- Under "Next-right actions", provide no more than three actions total.
- Do not suggest additional actions, tasks, questions to bring to
  someone, assignments, exercises, or follow-up activities anywhere
  outside the "Next-right actions" section.
- If you provide three next-right actions, do not add any other
  suggested action before or after that list.
- Prioritize appropriate human connection first.
- Significant Step decisions should be discussed with the user's
  sponsor or trusted recovery person.
- Do not decide that a Step is complete.
- Do not tell the user they may or may not advance to another Step.
- Do not diagnose motives, character defects, or spiritual condition
  as facts.
- Keep the response concise and practical.

Analyze only the supplied Step Work.
"""

    conversation = [
        {
            "role": "user",
            "content": step_work_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=step_prompt,
    )


# ============================================================
# Daily Check-In intelligence
# ============================================================

def analyze_checkin_trends(
    checkin_text: str,
) -> str:
    """
    Analyze recent Daily Check-In information.

    Completion counts are treated as observations rather than
    moral scores or measures of recovery worth.
    """

    conversation = [
        {
            "role": "user",
            "content": checkin_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=_SPECIALIZED_REFLECTION_PROMPT,
    )


# ============================================================
# Weekly Recovery Review intelligence
# ============================================================

def analyze_weekly_review(
    weekly_review_text: str,
) -> str:
    """
    Analyze one explicitly user-approved Weekly Recovery Review.

    The AI reflects on the supplied summary while avoiding judgment,
    diagnosis, or control over recovery progression.
    """

    conversation = [
        {
            "role": "user",
            "content": weekly_review_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=_SPECIALIZED_REFLECTION_PROMPT,
    )


# ============================================================
# Week-to-week comparison intelligence
# ============================================================

def analyze_weekly_comparison(
    comparison_text: str,
) -> str:
    """
    Analyze a user-approved comparison of two saved weekly reviews.

    Numerical increases and decreases are reported neutrally.
    Interpretation must remain tentative and recovery-centered.
    """

    comparison_prompt = """
You are analyzing a deterministic comparison of two Weekly Recovery Reviews.

The user explicitly chose to share this comparison for AI reflection.

Your role is to help the user reflect on changes between the two weeks without
judging recovery performance or treating numerical changes as inherently good
or bad.

Structure your response using exactly these sections:

Observed changes

Possible patterns to explore

Next-right actions

Requirements:

- Clearly distinguish observed changes from interpretation.
- Report increases, decreases, and unchanged activity neutrally.
- Do not describe a decrease as failure, regression, lack of commitment,
  backsliding, or evidence that recovery is worsening.
- Do not describe an increase by itself as proof that recovery is improving.
- Use tentative language such as "may," "might," "could," or "seems" when
  interpreting patterns or motives.
- Do not invent reasons for changes that are not present in the supplied data.
- Do not diagnose motives, character defects, or spiritual condition as facts.
- Do not determine whether a Step is complete or whether the user should
  progress to another Step.
- Prioritize human connection when suggesting next actions.
- Provide no more than three next-right actions total in the entire response.
- Do not suggest additional tasks, exercises, questions, assignments, or
  follow-up actions elsewhere in the response.
- Keep the response concise and practical.

Analyze only the supplied weekly comparison.
"""

    conversation = [
        {
            "role": "user",
            "content": comparison_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=comparison_prompt,
    )


# ============================================================
# Monthly Recovery Review intelligence
# ============================================================

def analyze_monthly_review(
    monthly_review_text: str,
) -> str:
    """
    Analyze an explicitly user-approved rolling four-week review.

    The AI reflects on the supplied deterministic summary without
    judging recovery performance or controlling Step progression.
    """

    conversation = [
        {
            "role": "user",
            "content": monthly_review_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=_SPECIALIZED_REFLECTION_PROMPT,
    )


# ============================================================
# Monthly comparison intelligence
# ============================================================

def analyze_monthly_comparison(
    comparison_text: str,
) -> str:
    """
    Analyze a user-approved comparison of two saved monthly reviews.

    The AI should describe changes neutrally, separate observation
    from interpretation, and avoid treating counts as recovery scores.
    """

    monthly_comparison_prompt = """
You are analyzing a deterministic comparison of two Monthly Recovery Reviews
for a Twelve-Step recovery companion.

The user explicitly chose to share this comparison for AI reflection.

Your role is to help the user reflect on changes between the two monthly
snapshots without judging recovery performance or turning numerical changes
into moral scores.

Structure your response using exactly these sections:

Observed changes

Possible patterns to explore

Next-right actions

Requirements:

- Clearly distinguish observed changes from interpretation.
- Report increases, decreases, and unchanged activity neutrally.
- Do not describe decreases as failure, regression, backsliding,
  lack of commitment, or evidence that recovery is worsening.
- Do not describe increases as proof that recovery is improving.
- Use tentative language such as "may," "might," "could," or "seems"
  when interpreting patterns, causes, or motives.
- Do not invent explanations that are not supported by the supplied data.
- Do not shame or moralize.
- Do not diagnose motives, character defects, or spiritual condition as facts.
- Do not determine Step completion or progression.
- Prioritize human connection when suggesting next actions.
- Provide no more than three next-right actions total in the entire response.
- Do not suggest additional tasks, exercises, assignments, questions,
  or follow-up actions elsewhere in the response.
- Keep the response concise and practical.

Analyze only the supplied Monthly Review Comparison.
"""

    conversation = [
        {
            "role": "user",
            "content": comparison_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=monthly_comparison_prompt,
    )


# ============================================================
# Recovery Insights intelligence
# ============================================================

def analyze_recovery_insights(
    insights_text: str,
) -> str:
    """
    Analyze an explicitly user-approved Recovery Insights summary.

    The AI should reflect on the combined daily, Step Work,
    weekly, and monthly data without turning the dashboard into
    a scorecard or making recovery decisions for the user.
    """

    conversation = [
        {
            "role": "user",
            "content": insights_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=_SPECIALIZED_REFLECTION_PROMPT,
    )