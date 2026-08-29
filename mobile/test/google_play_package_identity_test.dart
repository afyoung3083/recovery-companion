import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android package matches Google Play Recovery Companion listing', () {
    const expectedPackage = 'com.recoverycompanionlabs.recoverycompanion';

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    final activity = File(
      'android/app/src/main/kotlin/'
      'com/recoverycompanionlabs/recoverycompanion/'
      'MainActivity.kt',
    );

    expect(gradle, contains('namespace = "$expectedPackage"'));

    expect(gradle, contains('applicationId = "$expectedPackage"'));

    expect(activity.existsSync(), isTrue);

    expect(activity.readAsStringSync(), contains('package $expectedPackage'));
  });

  test(
    'old unavailable Play package is absent from Android release identity',
    () {
      const oldPackage = 'com.recoverycompanion.app';

      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, isNot(contains(oldPackage)));
    },
  );
}
