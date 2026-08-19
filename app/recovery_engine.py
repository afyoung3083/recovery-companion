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
    """

    system_prompt = load_system_prompt()

    return generate_response(
        conversation=conversation,
        instructions=system_prompt,
    )


# ============================================================
# Journal intelligence
# ============================================================

def analyze_journal_entry(
    entry_text: str,
) -> str:
    """
    Analyze one explicitly selected journal entry.

    The analysis emphasizes tentative interpretation, recovery
    strengths, human connection, and practical next-right actions.
    """

    journal_prompt = """
You are analyzing a journal entry for a Twelve-Step recovery companion.

The user explicitly chose to share this entry for analysis.

Identify, with humility and without diagnosis:

1. Recovery themes
2. Possible recurring patterns
3. Victories or evidence of progress
4. Items worth discussing with a sponsor or trusted recovery person
5. Up to three next-right actions, ranked by:
   - human connection
   - Higher Power connection
   - current Step work
   - service
   - journaling
   - amends

Rules:

- Do not claim certainty about motives, character defects, or spiritual condition.
- Every inferred motive, fear, recurring pattern, or character tendency must use
  explicitly tentative language such as "may," "might," "could," "possibly,"
  or "worth exploring."
- Never state an inferred recurring pattern as a fact, even when it seems likely.
- Clearly distinguish what the user actually wrote from what you are suggesting
  as a possibility.
- Do not shame.
- Do not treat the journal entry as a clinical record.
- Keep the response concise.
"""

    conversation = [
        {
            "role": "user",
            "content": entry_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=journal_prompt,
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

When responding:

1. Identify the current recovery theme or Step principle.
2. Reflect any progress already visible.
3. Note possible areas worth exploring, using tentative language.
4. Provide no more than three next-right actions total in the entire response.
   Do not suggest additional actions, tasks, questions to bring to someone,
   assignments, exercises, or follow-up activities anywhere else in the response.
   If you provide three next-right actions, do not add any other suggested action
   before or after that list.
5. Prioritize human connection first when appropriate.
6. Do not decide that a Step is complete.
7. Do not tell the user they may or may not advance to another Step.
8. Encourage the user to discuss significant Step decisions with their sponsor
   or trusted recovery person.
9. Do not diagnose motives, character defects, or spiritual condition as facts.
10. Keep the response concise and practical.
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

    checkin_prompt = """
You are analyzing recent Daily Recovery Check-In history.

The user explicitly chose to share these recent check-ins for analysis.

Your role is to support recovery without turning completion counts into a moral score.

When responding:

1. Identify visible strengths or areas of consistency.
2. Identify possible gaps or patterns worth exploring.
3. Use tentative language for any inferred motive, pattern, or cause.
4. Do not shame the user for incomplete actions.
5. Do not describe a lower completion count as failure.
6. Suggest up to three next-right actions.
7. Prioritize appropriate human connection first.
8. Keep recommendations practical and recovery-centered.
9. Do not diagnose motives, character defects, or spiritual condition as facts.
10. Clearly distinguish observed check-in data from interpretation.

Keep the response concise.
"""

    conversation = [
        {
            "role": "user",
            "content": checkin_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=checkin_prompt,
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

    weekly_prompt = """
You are analyzing a Weekly Recovery Review for a Twelve-Step recovery companion.

The user explicitly chose to share this weekly summary for AI reflection.

Your role is to support recovery without judging performance or replacing sponsors,
meetings, fellowship, therapy, clergy, or the user's Higher Power.

Structure your response using exactly these sections:

Observed strengths

Possible patterns to explore

Next-right actions

Requirements:

- Keep observation and interpretation strictly separate.
- In "Observed strengths", state only facts explicitly present in the supplied
  Weekly Recovery Review.
- In "Observed strengths", do not explain what any fact indicates, reflects,
  demonstrates, suggests, reveals, proves, or means.
- Do not infer honesty, acceptance, willingness, commitment, motivation,
  consistency, spiritual condition, or recovery progress in "Observed strengths"
  unless the supplied review explicitly states that fact.
- Put all interpretation exclusively in "Possible patterns to explore".
- Phrase every interpretation tentatively using language such as "may", "might",
  "could", "possibly", or "seems".
- Clearly distinguish observed data from interpretation.
- Treat recovery-action counts as descriptive information, not recovery scores.
- Do not describe low activity, missed actions, or incomplete recovery practices
  as failure, regression, backsliding, or evidence that recovery is worsening.
- Do not treat higher activity by itself as proof that recovery is improving.
- Do not shame or moralize the user's week.
- Do not invent explanations that are not supported by the supplied review.
- Do not diagnose motives, character defects, or spiritual condition as facts.
- Do not determine Step completion or progression.
- Prioritize human connection first when suggesting next actions.
- Provide no more than three next-right actions total in the entire response.
- Do not suggest additional tasks, exercises, questions, assignments, or
  follow-up actions elsewhere in the response.
- Keep recommendations practical and recovery-centered.
- Keep the response concise.

Example of acceptable separation:

Observed strengths
- Three check-in days were recorded.
- Two recovery contacts were recorded.

Possible patterns to explore
- The recovery contacts may suggest that connection was an active part of the week.

Do not write an observation like:
- Three check-in days were recorded, reflecting honesty and acceptance.

The phrase "reflecting honesty and acceptance" is interpretation and belongs only
in "Possible patterns to explore".

Analyze only the supplied Weekly Recovery Review.
"""

    conversation = [
        {
            "role": "user",
            "content": weekly_review_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=weekly_prompt,
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

    monthly_prompt = """
You are analyzing a rolling four-week Monthly Recovery Review for a
Twelve-Step recovery companion.

The user explicitly chose to share this monthly summary for AI reflection.

Your role is to help the user reflect on the supplied recovery activity without
judging performance or turning completion counts into a moral score.

Structure your response using exactly these sections:

Observed strengths

Possible patterns to explore

Next-right actions

Requirements:

- Clearly distinguish observed data from interpretation.
- Treat recovery-action counts as descriptive information, not scores.
- Do not describe lower activity, missed actions, or incomplete practices as
  failure, regression, backsliding, or evidence that recovery is worsening.
- Do not treat higher activity by itself as proof that recovery is improving.
- Use tentative language such as "may," "might," "could," or "seems" for
  inferred patterns, motives, or causes.
- Do not invent explanations that are not supported by the supplied summary.
- Do not shame or moralize.
- Do not diagnose motives, character defects, or spiritual condition as facts.
- Do not determine Step completion or progression.
- Prioritize human connection when suggesting next actions.
- Provide no more than three next-right actions total in the entire response.
- Do not suggest additional tasks, exercises, questions, assignments, or
  follow-up actions elsewhere in the response.
- Keep the response concise and practical.

Analyze only the supplied Monthly Recovery Review.
"""

    conversation = [
        {
            "role": "user",
            "content": monthly_review_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=monthly_prompt,
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

    insights_prompt = """
You are analyzing a deterministic Recovery Insights dashboard for a
Twelve-Step recovery companion.

The user explicitly chose to share this combined recovery summary for
AI reflection.

Your role is to help the user reflect on the supplied information without
judging performance, diagnosing motives, or replacing sponsors, fellowship,
therapy, clergy, or the user's Higher Power.

Structure your response using exactly these sections:

Observed strengths

Possible patterns to explore

Next-right actions

Requirements:

- Keep observation and interpretation strictly separate.
- In "Observed strengths", state only facts explicitly present in the supplied
  Recovery Insights summary. Do not explain what those facts indicate, reflect,
  demonstrate, suggest, or mean.
- Put all interpretation exclusively in "Possible patterns to explore".
- Phrase interpretations tentatively using language such as "may", "might",
  "could", or "possibly".
- Clearly distinguish observed data from interpretation.
- Treat counts, completion totals, and history as descriptive information,
  not recovery scores.
- Do not describe lower activity, missing data, or incomplete practices as
  failure, regression, backsliding, or evidence that recovery is worsening.
- Do not describe higher activity as proof that recovery is improving.
- Use tentative language such as "may," "might," "could," or "seems" when
  interpreting possible patterns, motives, or causes.
- Do not invent explanations that are not supported by the supplied summary.
- Do not shame or moralize.
- Do not diagnose motives, character defects, or spiritual condition as facts.
- Do not determine Step completion or progression.
- Prioritize human connection when suggesting next actions.
- Provide no more than three next-right actions total in the entire response.
- Do not suggest additional tasks, exercises, assignments, questions, or
  follow-up actions elsewhere in the response.
- Keep the response concise and practical.

Analyze only the supplied Recovery Insights summary.
"""

    conversation = [
        {
            "role": "user",
            "content": insights_text,
        }
    ]

    return generate_response(
        conversation=conversation,
        instructions=insights_prompt,
    )