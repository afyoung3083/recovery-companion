# Google Play Closed-Beta Readiness

## Android artifact

- Application ID: `com.recoverycompanionlabs.recoverycompanion`
- App name: Recovery Companion
- Version name: `1.22.0`
- Version code: `9`
- Target SDK: Android 16 / API 36
- Distribution artifact: signed Android App Bundle (`.aab`)
- Release signing: dedicated Recovery Companion upload key
- Android backup: disabled
- Production API: https://api.recoverycompanionlabs.com
- Sprint 57 corrected candidate: 1.22.0+9
"@
)

# Google Play Closed-Beta Readiness

## Android artifact

- Application ID: `com.recoverycompanionlabs.recoverycompanion`
- App name: Recovery Companion
- Version name: `1.22.0`
- Version code: `9`
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
 = [regex]::Replace(
    # Google Play Closed-Beta Readiness

## Android artifact

- Application ID: `com.recoverycompanionlabs.recoverycompanion`
- App name: Recovery Companion
- Version name: `1.22.0`
- Version code: `9`
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
,
    '(?s)## Testing track.*?\r?\n## Release artifact',
@"
## Testing track

Sprint 57 uses Google Play Internal testing as the physical-device release
gate before updating the existing Closed testing track.

The corrected 1.22.0+9 candidate must first be installed through Google Play
Internal testing as an in-place upgrade.

Required checks:

- existing encrypted local data remains available;
- Recovery Companion Chat reaches the production AI service;
- Daily Recovery optional AI perspective succeeds;
- a newly saved local Journal entry appears in Journal History;
- Reflect with AI is enabled for that local Journal entry;
- Journal AI requires explicit confirmation;
- Journal AI returns a production response;
- local recovery records remain available if AI connectivity is unavailable.

Only after those checks pass should the same Play artifact be made available
to the existing Closed testing group.

## Release artifact

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
