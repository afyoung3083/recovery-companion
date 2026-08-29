# Android Release Signing Recovery

Recovery Companion Android releases use a dedicated upload key.

## Production identity

- Application ID: `com.recoverycompanionlabs.recoverycompanion`
- Key alias: `recovery-companion-upload`
- Keystore filename: `recovery-companion-upload.jks`

## Security model

The private upload keystore and `android/key.properties` are never
committed to Git.

The keystore is password protected. Its password must be stored separately in a password manager.
It must not be stored in this repository, documentation, GitHub issues,
CI logs, or source code.

A disaster-recovery backup should contain:

- `recovery-companion-upload.jks`
- the exported public certificate
- public certificate fingerprints
- the SHA-256 checksum of the keystore
- recovery instructions

It should **not** contain `key.properties`.

## Recovery procedure

1. Restore `recovery-companion-upload.jks`.
2. Retrieve its password from the separately maintained password
   manager entry.
3. Recreate `mobile/android/key.properties` locally using:
   - the store password from the password manager
   - the key password from the password manager
   - key alias `recovery-companion-upload`
   - keystore filename `recovery-companion-upload.jks`

   Do not copy a password value into documentation, source control,
   tickets, chat, or build logs.

4. Confirm both signing files remain ignored by Git.
5. Run `keytool -list -v` against the restored keystore.
6. Compare the certificate SHA-256 fingerprint with the value recorded
   in the off-repository recovery metadata.
7. Build and verify a signed release artifact before publishing.

## Never

- Commit the keystore.
- Commit `key.properties`.
- Paste signing passwords into GitHub, chat, issue trackers, or logs.
- Generate a replacement key merely because a workstation copy was
  lost.
- Store the only backup on the same workstation as the source tree.

Google Play upload-key recovery procedures may change over time. Check
current Google Play documentation before performing a key-reset action.
