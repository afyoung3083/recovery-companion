# Android Beta Release Validation

This procedure validates the signed Android beta artifact before release to
the closed-testing group.

## Production Android identity

- Application ID: `com.recoverycompanionlabs.recoverycompanion`
- Application label: `Recovery Companion`
- Previous closed-beta version: `1.21.0+6`
- Sprint 57 corrected candidate: `1.22.0+8`
- Upload-key alias: `recovery-companion-upload`
- Production API: `https://api.recoverycompanionlabs.com`

## Build the candidate

Build from a clean working tree using the ignored local production dart-define
file:

`flutter build appbundle --release --dart-define-from-file=.dart-defines.production.json`

Verify the AAB cryptographic signature with the dedicated Recovery Companion
upload certificate before uploading to Google Play.

Do not commit `.dart-defines.production.json` or expose the beta API token in
logs, screenshots, documentation, or shell history.

## Google Play internal test

Upload the candidate to the Google Play Internal testing track first. Use only
the dedicated internal tester account during this gate.

Verify:

- package is `com.recoverycompanionlabs.recoverycompanion`
- version name is `1.22.0`
- version code is `8`
- Google Play accepts the signed AAB without a signing or package error

Before updating, preserve at least one recognizable local-first record. A
journal entry such as `SPRINT 57 UPGRADE PRESERVATION TEST` is suitable.

Update the already-installed Play beta through Google Play. Do not uninstall
the app or clear its data.

Verify after the Play update:

- Android treats the operation as an upgrade rather than a fresh install
- version code becomes `8`
- version name is `1.22.0`
- the app launches successfully
- onboarding completion remains intact
- the distinctive local recovery record still exists
- existing goals, routines, reminders, and other local-first records remain available
- local encrypted recovery data survives the upgrade

## Production AI physical-device checks

With the development computer irrelevant to the request path, verify on a
physical Android phone:

1. Recovery Companion Chat returns a real AI response over cellular data.
2. Daily Recovery optional AI perspective returns a real AI response.
3. A newly saved local-first Journal entry appears in Journal History.
4. `Reflect with AI` is enabled for that local Journal entry.
5. Journal reflection requires explicit confirmation before transmission.
6. The reflection returns successfully from the production AI service.
7. With connectivity disabled, AI actions fail safely while local recovery records remain available.

Journal entries that predate the authoritative local-first Journal cutover are
outside this upgrade-preservation gate unless they were migrated into the
encrypted local store. Do not represent absent legacy development data as data
lost by the current Play upgrade.

## Privacy and platform checks

The release manifest must continue to specify:

- `android:allowBackup="false"`
- application label `Recovery Companion`

Release signing must use the dedicated Recovery Companion upload key, not the
Android debug key.

## Pass criteria

The release candidate passes when:

1. the signed release AAB verifies cryptographically;
2. Google Play accepts the signed AAB;
3. build 8 upgrades the existing Play installation successfully;
4. local encrypted recovery data survives the upgrade;
5. package identity and version information are correct;
6. backup remains disabled;
7. Chat, Daily Recovery AI, and Journal AI work through the production API;
8. offline AI failure leaves local recovery records available;
9. the working tree remains clean after validation.
