# Google Play App Content Declarations

This document records the intended Recovery Companion Play Console
answers supported by the current application.

## Privacy policy

Use:

https://afyoung3083.github.io/recovery-companion/privacy/

The URL must be verified live after GitHub Pages is enabled from the
merged `main` branch.

## Ads

Provisional answer:

**No, Recovery Companion does not contain ads.**

Current source review identifies no Google Mobile Ads / AdMob integration.

Reassess this answer if advertising or sponsored-content SDKs are added.

## App access

Recovery Companion does not currently present a normal end-user account
sign-in screen as a prerequisite for accessing the local recovery
application.

Provisional Play position:

**All or substantially all core app functionality is available without
a user login.**

Before submission, verify the production build installed from Google
Play can reach every area needed by a Google reviewer.

If any online feature requires special backend credentials, allowlisting,
invitation state, or another restriction not available to reviewers,
provide Play Console App Access instructions.

Do not provide secret API keys or administrative credentials as reviewer
instructions.

## Target audience

Recommended intended audience:

**Adults**

Do not select child age groups merely to maximize distribution.

Recovery Companion handles sensitive addiction/recovery information and
is designed around adult recovery concepts, Twelve-Step participation,
sponsors, fellowship, Step Work, and optional AI reflection.

Before submitting, select the appropriate adult age groups offered by
the current Play Console interface.

If Recovery Companion is intentionally expanded to minors in the future,
perform a separate Families-policy, privacy, safeguarding, and product
review first.

## Content rating

Complete the IARC content-rating questionnaire truthfully.

Do not manually choose or predict the final regional rating. Google Play
and participating rating authorities derive ratings from questionnaire
answers.

Consider the actual application content when answering, including:

- addiction/recovery subject matter
- user-generated journal and chat content
- AI-generated recovery conversation
- references to sensitive behavioral-health subjects
- whether users can enter language or descriptions involving mature
  experiences

Do not characterize user-generated or AI-generated content more narrowly
than the released application allows.

## Health Apps

Select:

**Mental and Behavioral Health**

See:

`docs/google-play-health-declaration-final.md`

## Data Safety

Use the evidence-backed working declaration in:

`docs/google-play-data-safety-draft.md`

and:

`docs/google-play-data-safety-evidence.md`

Do not select ephemeral processing under the current evidence model.

The final "sharing" determination remains subject to provider and
service-provider verification.

## Permissions

The Sprint 53 release audit identified normal application permissions
including Internet, notifications, vibration, and boot-completed
behavior.

If Play Console requests any additional permission declaration based on
the uploaded AAB, stop and assess that declaration against the actual
bundle before answering.

## News

Recovery Companion is not a News app.

## Government

Recovery Companion is not a government app.

## Financial features

Recovery Companion does not provide financial products, lending,
banking, investing, cryptocurrency, or other financial-service features.

## Reviewer consistency rule

Every Play Console answer must match:

- the released Android App Bundle
- the in-app disclosures
- the public privacy policy
- current backend behavior
- current external provider configuration

When those disagree, correct the product or documentation before
submitting.
