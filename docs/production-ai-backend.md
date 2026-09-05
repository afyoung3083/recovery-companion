# Production AI Backend

## Status

**Sprint 57 status: production AI service is live.**

Recovery Companion now uses the production HTTPS API at:
https://api.recoverycompanionlabs.com
Render deployment, the public route boundary, authentication, request limits,
security headers, production AI endpoints, custom-domain HTTPS, and physical
Android connectivity have been verified.

Google Play Internal testing confirmed that build 1.22.0+7 upgraded the
existing app without losing encrypted local recovery data. Recovery Companion
Chat and Daily Recovery AI also worked from a physical Android phone over
cellular data.

Build 1.22.0+9 is the corrected Sprint 57 candidate. It fixes Journal AI
reflection for authoritative local-first Journal entries.

## Purpose

The production backend is a stateless AI gateway for the local-first
Recovery Companion mobile application.

Authoritative recovery records remain on the user's device.

The public backend receives only information that a user explicitly
submits for an AI operation. It does not provide public server-side CRUD
operations for Journal, Goals, Routines, Fellowship, Step Work, Profile,
Daily Recovery storage, reviews, export, deletion, or synchronization.

The legacy development API remains in `app/api.py` for local development
and compatibility testing.

Render must run:

```text
app.production_api:app
```

It must not run:

```text
app.api:app
```

## Public route surface

The production service exposes only:

```text
GET  /health
POST /chat
POST /recovery-insights/ai-reflection
POST /daily-checkin/ai-reflection
POST /journal/{entry_id}/ai-reflection
POST /weekly-review/ai-reflection
POST /monthly-review/ai-reflection
```

Interactive API documentation and the OpenAPI document are disabled.

Every AI endpoint requires an explicit request body. The production
service does not fall back to loading recovery records from server-side
files.

## Required environment variables

Render must receive these values outside Git:

```text
RECOVERY_ENVIRONMENT=production
OPENAI_API_KEY=<server-side OpenAI API key>
RECOVERY_API_TOKEN=<random closed-beta token of at least 32 characters>
```

Never place either secret in source control, `render.yaml`, build logs,
screenshots, support email, issue text, or public documentation.

The OpenAI key belongs only on the backend. It must never be compiled
into the Android application.

## Temporary closed-beta authentication

`RECOVERY_API_TOKEN` is a temporary closed-beta control.

A shared token compiled into a mobile application can eventually be
extracted. It is therefore not the final public identity architecture.

Before broad production release, replace it with a per-user or
per-install identity design and add stronger device/app attestation as
appropriate.

For the limited closed beta, the gateway also applies request limits,
input-size limits, a narrow route surface, and a single-instance cost
boundary.

## Request and cost guardrails

Default production settings:

```text
RECOVERY_MAX_REQUEST_BYTES=65536
RECOVERY_RATE_LIMIT_REQUESTS=30
RECOVERY_RATE_LIMIT_WINDOW_SECONDS=60
```

Application-level AI text and chat limits are also enforced.

The rate limiter is intentionally process-local. The Render Blueprint
therefore uses one service instance and one Uvicorn worker.

Do not increase workers or instances until rate limiting is moved to a
shared service such as a managed key-value store.

## Privacy and logging

The production API:

- does not persist request bodies;
- does not expose server-side recovery-data storage routes;
- disables Uvicorn access logging in the Render start command;
- returns generic validation, provider, and unexpected-error messages;
- does not include user input in validation responses;
- applies `Cache-Control: no-store`;
- does not enable browser CORS because the Android app is a native client.

Disabling application access logs does not prove that every
infrastructure provider retains no metadata. Render, network, and OpenAI
processing must remain accurately described in the privacy policy and
Google Play Data Safety declarations.

## Render Blueprint

The root `render.yaml` defines:

- a Python web service;
- the Virginia region;
- the smallest paid web-service compute plan;
- one instance;
- one Uvicorn worker;
- dynamic binding to Render's `$PORT`;
- `/health` HTTP health checks;
- deployment only after linked-branch checks pass;
- secret prompting for `OPENAI_API_KEY` and `RECOVERY_API_TOKEN`;
- no database and no persistent disk.

Creating or syncing the Blueprint in Render is an external action and
may create a billable service. Sprint 57 Slice 1 does not perform that
action.

## CI

`.github/workflows/backend-ci.yml` runs for backend-affecting pull
requests and for qualifying pushes to `main`.

It compiles the production modules, tests the public production
boundary, and runs the complete Python test suite.

The push-to-main check is required because the Render Blueprint uses:

```text
autoDeployTrigger: checksPass
```

## Verified Sprint 57 deployment

Sprint 57 verified this production path:
Android phone
-> https://api.recoverycompanion.com
-> Render production API
-> OpenAI Responses API


Verified behavior includes:

- /health succeeds over the custom HTTPS domain;
- undocumented recovery-data CRUD routes return 404;
- API docs and OpenAPI routes are disabled;
- missing or incorrect beta credentials return 401;
- all intended production AI endpoints respond successfully;
- oversized request bodies are rejected;
- responses include no-store security controls;
- application request bodies are not intentionally logged;
- authoritative recovery records remain local-first;
- existing encrypted local data survives Google Play upgrades;
- Recovery Companion Chat works from a physical phone;
- Daily Recovery optional AI perspective works from a physical phone;
- Journal AI supports explicitly selected local-first Journal entries.

The shared closed-beta bearer credential remains temporary and must be
replaced before broad production distribution with stronger identity and
device/app-attestation controls.