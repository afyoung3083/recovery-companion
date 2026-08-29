import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android beta release identity and privacy settings are locked', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(
      gradle,
      contains('applicationId = "com.recoverycompanionlabs.recoverycompanion"'),
    );

    expect(manifest, contains('android:label="Recovery Companion"'));

    expect(manifest, contains('android:allowBackup="false"'));

    expect(gradle, contains('signingConfigs.getByName("release")'));

    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('Android beta validation runbook requires upgrade preservation', () {
    final runbook = File('../docs/android-beta-release-validation.md')
        .readAsStringSync();

    expect(runbook, contains('SPRINT 53 UPGRADE PRESERVATION TEST'));

    expect(
      runbook,
      contains('local encrypted recovery data survives the upgrade'),
    );

    expect(runbook, contains('version code becomes `7`'));

    expect(runbook, contains('working tree remains clean'));
  });
}
