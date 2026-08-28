import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closed beta checklist preserves Play release requirements', () {
    final checklist = File('../docs/google-play-closed-beta-readiness.md')
        .readAsStringSync();

    expect(checklist, contains('Android 16 / API 36'));

    expect(checklist, contains('Data safety'));

    expect(checklist, contains('Health apps declaration'));

    expect(checklist, contains('public privacy-policy URL'));

    expect(checklist, contains('app-release.aab'));
  });

  test('health draft classifies addiction recovery correctly', () {
    final health = File('../docs/google-play-health-declaration-draft.md')
        .readAsStringSync();

    expect(health, contains('Mental and Behavioral Health'));

    expect(health, contains('not a medical device'));

    expect(health, contains('not an emergency or crisis-response service'));
  });

  test('data safety draft does not falsely claim zero collection', () {
    final dataSafety = File('../docs/google-play-data-safety-draft.md')
        .readAsStringSync();

    expect(dataSafety, contains('Health info'));

    expect(dataSafety, contains('Other user-generated content'));

    expect(dataSafety, contains('DO NOT ASSUME'));

    expect(dataSafety, contains('Do not guess'));
  });
}
