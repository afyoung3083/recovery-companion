# Android Beta Release Validation

This procedure validates the signed Android beta artifact before release.

## Production Android identity

- Application ID: `com.recoverycompanion.app`
- Application label: `Recovery Companion`
- Source version: `1.21.0+6`
- Upload-key alias: `recovery-companion-upload`

## Baseline release installation

Build and install the signed release artifact using the committed build
number.

Verify:

- package is `com.recoverycompanion.app`
- version name is `1.21.0`
- version code is `6`
- the app launches successfully in release mode
- first-run onboarding works
- local recovery data can be created

Create a distinctive local test record before the upgrade. A journal
entry such as `SPRINT 53 UPGRADE PRESERVATION TEST` is suitable.

## Upgrade simulation

Build the same source again with build number `7` supplied only as a
Flutter command-line build override.

Do not commit that temporary build number.

Install the build-7 APK over build 6 with Android's replace-install
behavior.

Verify:

- Android treats the operation as an upgrade rather than a fresh install
- version code becomes `7`
- version name remains `1.21.0`
- the app launches successfully
- onboarding completion remains intact
- the distinctive local recovery record still exists
- existing goals, routines, reminders, and other local-first records
  remain available

## Privacy and platform checks

The release manifest must continue to specify:

- `android:allowBackup="false"`
- application label `Recovery Companion`

Release signing must use the dedicated Recovery Companion upload key,
not the Android debug key.

## Pass criteria

The release candidate passes when:

1. the signed release APK verifies cryptographically;
2. build 6 installs and launches;
3. build 7 upgrades build 6 successfully;
4. local encrypted recovery data survives the upgrade;
5. package identity and version information are correct;
6. backup remains disabled;
7. the working tree remains clean after validation.
