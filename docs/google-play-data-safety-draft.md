# Google Play Data Safety ? Draft

This is a working declaration aid, not a completed legal or Play
Console submission.

## Architecture facts

Recovery Companion is local-first.

Core recovery records are stored locally and are not automatically sent
off-device merely because a user creates or views them.

Some explicitly requested online features do transmit information:

- Recovery Companion chat
- AI Journal reflection
- AI Daily Recovery reflection
- AI Recovery Insights reflection
- AI Weekly Review reflection
- AI Monthly Review reflection

Google Play defines data sent off-device as collection, including data
processed ephemerally.

## Likely data categories to evaluate

### Health info

Recovery and addiction-related information may constitute Health info.

**Likely collection:** Yes, when a user explicitly invokes an online
AI/chat feature containing recovery information.

**Required or optional:** Optional. The local-first app can be used
without requesting AI reflection.

**Purpose:** App functionality.

### Other user-generated content

Journal text, check-in text, review summaries, and chat messages can
qualify as Other user-generated content.

**Likely collection:** Yes, when explicitly transmitted for AI/chat
functionality.

**Required or optional:** Optional.

**Purpose:** App functionality.

## Ephemeral processing ? DO NOT ASSUME

Google Play permits an ephemeral-processing designation only when the
off-device data is retained in memory no longer than necessary to
service the real-time request.

Before submission, verify:

- Recovery Companion backend logging behavior
- AI-provider retention behavior
- infrastructure request/access logs
- error/telemetry logging
- whether prompts or responses are persisted anywhere off-device

Do not mark processing as ephemeral until those facts are verified.

## Sharing ? VERIFY BEFORE ANSWERING

Google Play has specific exceptions for service providers and certain
user-initiated transfers.

Before answering whether data is shared, verify:

- identity and role of every external AI/cloud provider
- applicable data-processing terms
- whether any provider uses data for its own purposes
- whether any provider qualifies as a service provider under Play's
  definition

Do not guess.

## Other categories

Review the final app and SDK inventory for:

- Diagnostics
- Crash logs
- Device or other IDs
- Approximate location inferred from network information
- App interactions
- Personal information

Do not declare a category merely because it exists in Google's form;
declare it only when the released app or its SDKs actually collect it.

## Security statements to verify

Before submission confirm:

- transmitted user data uses HTTPS/TLS
- authoritative local recovery data is encrypted
- Android application backup remains disabled
- users can delete Recovery Companion-owned recovery data
- Data safety answers match the public privacy policy
