# Google Play Data Safety ? Working Declaration

This document is a working aid for the Google Play Data Safety form.

The evidence supporting these answers is maintained in:

`docs/google-play-data-safety-evidence.md`

## Current provisional answers

### Health info

Recovery Companion may transmit addiction/recovery information when the
user explicitly requests an AI reflection or uses companion chat.

- Collected: **Yes**
- Required or optional: **Optional**
- Purpose: **App functionality**
- Ephemeral processing: **No / do not select at this time**

### Other user-generated content

Journal text, check-in text, review summaries, Step Work explicitly
submitted to AI, and chat messages may be transmitted for optional
online functionality.

- Collected: **Yes**
- Required or optional: **Optional**
- Purpose: **App functionality**
- Ephemeral processing: **No / do not select at this time**

## Why ephemeral is not selected

The backend uses the OpenAI Responses API with `store=False`.

That setting is useful, but it is not proof that the provider performs
Zero Data Retention.

Current provider policy may permit API inputs and outputs to be retained
for a limited abuse-monitoring period.

Do not mark these categories ephemeral unless production provider
configuration is later verified to satisfy Google's definition.

## Sharing

**PENDING VERIFICATION**

Do not answer this based solely on the fact that an external provider
processes an API request.

The final Play answer depends on Google's service-provider rules and the
production contractual/provider relationship.

## Model training

OpenAI API data is not used for model training by default unless the API
customer explicitly opts in.

Verify that the production project remains opted out before Play
submission.

## Remaining production checks

Before submitting Data Safety:

- verify production API hostname and HTTPS
- verify release configuration uses that HTTPS endpoint
- review backend request logging
- review cloud/reverse-proxy logging
- review monitoring/error telemetry
- verify OpenAI project data-sharing configuration
- verify whether Zero Data Retention applies
- determine final service-provider/sharing treatment
- review every production SDK/provider that receives user information

The Play declaration and published privacy policy must agree with the
verified production behavior.
