# Google Play Closed-Test Operations

## Purpose

This runbook defines how Recovery Companion closed-beta builds are
distributed and how testers are admitted, removed, and supported.

No tester email addresses are stored in this repository.

## Recommended access model

Use a dedicated Google Group for the Recovery Companion closed beta.

Example administrative concept:

`recovery-companion-beta-testers@googlegroups.com`

The actual group address is configured outside the repository.

Reasons to prefer a Google Group:

- tester membership can change without changing source code
- individual tester addresses do not enter Git history
- removing a tester requires removing group membership rather than
  editing release documentation
- the same testing track can be reused across beta releases

## Play Console track

Navigate to:

Test and release > Testing > Closed testing

Use a dedicated closed-testing track for the Recovery Companion beta.

Recommended track name:

`closed-beta`

If a suitable closed-testing track already exists, reuse it rather than
creating duplicate tracks.

## Configure testers

Within the closed-testing track:

1. Open the Testers tab.
2. Choose Google Groups.
3. Enter the dedicated beta tester Google Group address.
4. Configure the beta feedback email or URL.
5. Save changes.
6. Copy the Play Console shareable tester link.

Only members of the configured Google Group should be admitted to this
closed test.

Do not place individual tester email addresses in repository files.

## Release creation

For each beta release:

1. Confirm the branch/release candidate has passed its release audit.
2. Build the signed Android App Bundle.
3. Verify package identity and signing.
4. Confirm the version code is greater than every previously uploaded
   version code.
5. Open the `closed-beta` track.
6. Select Create new release.
7. Upload the `.aab` artifact.
8. Add release notes.
9. Review warnings and errors.
10. Resolve blocking errors before rollout.
11. Save/review the release.
12. Start rollout to the closed-testing track.

The Google Play artifact is:

`mobile/build/app/outputs/bundle/release/app-release.aab`

Do not upload the APK as the Play Store release artifact.

## Version-code rule

Google Play requires each uploaded Android release to use a version code
that has not already been used for that application.

Never reuse a version code after it has been uploaded to Play Console,
even if the corresponding release was later abandoned.

Maintain version progression through the normal Recovery Companion
versioning process.

## Tester opt-in

The tester receives:

1. membership in the approved Google Group
2. the Play closed-test opt-in link
3. the Recovery Companion tester onboarding instructions

A tester must use an eligible Google account.

For Google Group based closed tests, the tester must join the approved
group before opting into the test.

The app may not be discoverable through ordinary Google Play search.
Use the tester opt-in/shareable link supplied by Play Console.

## Tester invitation sequence

Recommended invitation message order:

1. Confirm the tester wants to participate.
2. Add the tester's Google account to the beta group.
3. Send the opt-in link.
4. Ask the tester to opt in.
5. Ask the tester to install from Google Play.
6. Direct the tester to the in-app Closed Beta Tester Guide.
7. Explain how to use Beta Feedback & Support.
8. Ask the tester to install subsequent beta updates through Google Play.

## Tester removal

To remove access:

1. Remove the tester from the beta Google Group.
2. Do not delete or modify their Google account.
3. Do not request recovery data from their device.
4. Record only administrative beta status outside source control if
   needed.

Removing a tester from the closed test prevents future beta access but
does not remotely erase an already installed app or the tester's local
Recovery Companion records.

## Feedback channel

Play Console should contain a direct beta feedback destination.

The tester can also use Recovery Companion's in-app Beta Feedback &
Support screen to create a privacy-conscious report.

Do not direct testers to publish beta defects as public Google Play
reviews.

## Release pause

If a beta release contains a serious defect:

1. Pause or stop the applicable testing release/track in Play Console.
2. Triage the problem.
3. Prioritize:
   - data loss
   - security/privacy
   - crashes blocking normal use
4. Prepare a corrected build using a new version code.
5. Re-run release validation.
6. Upload the corrected AAB.
7. Notify testers when the corrected build is available.

## Secrets

Never distribute or upload these to testers:

- `mobile/android/key.properties`
- the Android upload keystore
- signing passwords
- API tokens
- backend administrative credentials

Google Play receives the signed AAB, not the private signing material.
