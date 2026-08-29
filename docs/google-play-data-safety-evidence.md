# Google Play Data Safety Evidence

## Purpose

This document separates verified Recovery Companion behavior from
assumptions that must not be entered into Google Play Console.

## Architecture evidence

Recovery Companion is local-first.

Authoritative recovery records are stored locally on the user's device.

Creating, reading, or editing a local recovery record does not by itself
send that record to an AI provider.

Online transmission occurs only when the user invokes functionality that
requires the Recovery Companion backend, including optional AI and chat
features.

## AI provider

The current backend AI provider is OpenAI.

The backend uses the OpenAI Responses API.

The common AI client calls the API with:

`store=False`

This prevents the generated Responses API object from being stored for
later retrieval through that API.

`store=False` MUST NOT be interpreted as proof of Zero Data Retention.

## Provider retention

Current OpenAI API documentation states that, except for qualifying
zero-data-retention configurations and certain endpoint-specific
exceptions, API inputs and outputs may be retained for up to 30 days for
service delivery and abuse monitoring.

Recovery Companion has not established evidence in this repository that
the production OpenAI project is approved for and configured with Zero
Data Retention.

Therefore:

**Do not classify Recovery Companion AI processing as ephemeral in
Google Play Data Safety at this time.**

## Model training

Current OpenAI business/API policy states that API inputs and outputs are
not used for model training by default unless the customer explicitly
opts in.

Recovery Companion should not enable provider model-training opt-in for
production recovery data.

Before release, verify the production OpenAI project's data-sharing
settings in the provider account.

## Data categories

### Health information

Addiction and recovery information can constitute health information.

Recovery Companion can transmit health-related recovery information when
a user explicitly requests an AI reflection or uses companion chat.

Provisional Play declaration:

- Collected: Yes
- Required: No / optional
- Purpose: App functionality
- Ephemeral processing: No, unless production retention evidence changes

### Other user-generated content

Journal entries, check-in text, review summaries, Step Work submitted to
AI, and chat messages can constitute user-generated content.

Provisional Play declaration:

- Collected: Yes
- Required: No / optional
- Purpose: App functionality
- Ephemeral processing: No, unless production retention evidence changes

## Local-only information

Information that remains exclusively in local application storage is not
sent off-device merely because Recovery Companion stores or displays it.

The Data Safety declaration must nevertheless consider any instance in
which that information is later explicitly transmitted through an online
feature.

## Sharing

Do not yet answer Google's "shared" question solely from source code.

The final answer depends on the applicable Google Play definition of a
service provider and the production provider relationship and terms.

Before submitting:

1. Identify every production infrastructure and AI provider that receives
   user data.
2. Confirm whether each provider processes that information solely on
   Recovery Companion's behalf.
3. Review applicable contracts/data-processing terms.
4. Determine the Google Play Data Safety service-provider treatment.
5. Record the evidence supporting the final answer.

## Application/backend logging

A source-code review must verify whether Recovery Companion itself logs:

- request bodies
- AI prompts
- AI responses
- journal text
- chat text
- authentication tokens

Production infrastructure must also be reviewed independently because
reverse proxies, cloud platforms, monitoring systems, or access-log
services may collect metadata even when application source code does not
explicitly log request bodies.

## Transmission security

The production online service must use HTTPS/TLS.

The mobile development default URL is not evidence of the production
deployment configuration.

Before Play submission:

1. identify the production API hostname;
2. verify it uses HTTPS;
3. verify the release build points to that HTTPS endpoint;
4. verify no production user-data request falls back to cleartext HTTP.

## Deletion

Local Recovery Companion-owned recovery information can be deleted using
the application's Settings & Privacy controls.

Provider-side retention/deletion is separate from local deletion.

Do not claim that deleting local data immediately deletes copies subject
to provider abuse-monitoring or infrastructure retention periods unless
that behavior is separately verified.

## Final Play Console position

Until all production infrastructure checks are complete:

- Health info: collected for optional online functionality
- Other user-generated content: collected for optional online
  functionality
- Purpose: app functionality
- Required: optional
- Ephemeral: do not select
- Sharing: pending provider/service-provider verification
- Training: provider API data not used for training by default; verify
  production account remains opted out
