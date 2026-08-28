import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release uses release signing', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('rootProject.file("key.properties")'));

    expect(gradle, contains('create("release")'));

    expect(gradle, contains('signingConfigs.getByName("release")'));

    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
  });

  test('Android signing secrets are gitignored', () {
    final gitignore = File('../.gitignore').readAsStringSync();

    expect(gitignore, contains('mobile/android/key.properties'));

    expect(
      gitignore,
      contains(
        'mobile/android/app/'
        'recovery-companion-upload.jks',
      ),
    );
  });
}
