import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release identity is production-safe', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    final activity = File(
      'android/app/src/main/kotlin/'
      'com/recoverycompanionlabs/recoverycompanion/'
      'MainActivity.kt',
    );

    expect(
      gradle,
      contains(
        'namespace = '
        '"com.recoverycompanionlabs.recoverycompanion"',
      ),
    );

    expect(
      gradle,
      contains(
        'applicationId = '
        '"com.recoverycompanionlabs.recoverycompanion"',
      ),
    );

    expect(gradle, isNot(contains('com.example.mobile')));

    expect(
      manifest,
      contains(
        'android:label='
        '"Recovery Companion"',
      ),
    );

    expect(activity.existsSync(), isTrue);

    expect(
      activity.readAsStringSync(),
      contains(
        'package '
        'com.recoverycompanionlabs.recoverycompanion',
      ),
    );
  });

  test('Sprint 53 beta version is 1.21.0+6', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 1.21.0+6'));
  });
}
