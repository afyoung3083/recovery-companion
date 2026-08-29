# Google Play Closed-Beta Readiness

## Android artifact

- Application ID: `com.recoverycompanionlabs.recoverycompanion`
- App name: Recovery Companion
- Version name: `1.21.0`
- Version code: `6`
- Target SDK: Android 16 / API 36
- Distribution artifact: signed Android App Bundle (`.aab`)
- Release signing: dedicated Recovery Companion upload key
- Android backup: disabled

## Google Play policy setup

Before publishing to a closed-testing track, complete Play Console
**App content** requirements including:

- Privacy policy
- Ads declaration
- App access declaration
- Target audience and content
- Content rating
- Data safety
- Health apps declaration
- Any additional declarations Play Console identifies for this app

## Privacy policy

Recovery Companion contains in-app Privacy & Health Information.

The production public privacy-policy URL is:

`https://afyoung3083.github.io/recovery-companion/privacy/`

The policy source is maintained in:

`docs/privacy/index.md`

Before entering the URL into Play Console, verify that the published
GitHub Pages URL loads successfully without authentication.

## Health apps declaration

Recovery Companion provides addiction-recovery functionality.

Use the Google Play Health Apps declaration and declare:

- **Mental and Behavioral Health**

The app is recovery-support software, not a medical device.

Review the separate health declaration draft before submitting.

## Data safety

Closed testing requires a completed Data safety declaration.

Do not simply answer that the app collects no data.

Most recovery records are processed locally, but explicit AI reflection
and chat operations transmit user-provided information off-device.

Review the separate Data safety draft and verify actual server/provider
retention before submitting the form.

## Testing track

Use a Google Play testing track appropriate to the developer account.

Closed-test participants need eligible Google accounts and must opt in
through the testing link.

## Release artifact

Upload:

`mobile/build/app/outputs/bundle/release/app-release.aab`

Do not upload the APK as the Play Store release artifact.

The APK remains useful for direct release-install validation.
