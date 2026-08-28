import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closed beta checklist preserves Play release requirements', () {
    final checklist = File('../docs/google-play-closed-beta-readiness.md')
        .readAsStringSync();

    expect(checklist, contains('Android 16 / API 36'));

    expect(checklist, contains('Data safety'));

    expect(checklist, contains('Health apps declaration'));

    expect(
      checklist,
      contains(
        'https://afyoung3083.github.io/'
        'recovery-companion/privacy/',
      ),
    );

    expect(checklist, contains('app-release.aab'));
  });

  test('health draft classifies addiction recovery correctly', () {
    final health = File('../docs/google-play-health-declaration-draft.md')
        .readAsStringSync();

    expect(health, contains('Mental and Behavioral Health'));

    expect(health, contains('not a medical device'));

    expect(health, contains('not an emergency or crisis-response service'));
  });

  test('data safety draft uses evidence-backed conservative answers', () {
    final dataSafety = File('../docs/google-play-data-safety-draft.md')
        .readAsStringSync();

    expect(dataSafety, contains('Health info'));

    expect(dataSafety, contains('Other user-generated content'));

    expect(dataSafety, contains('Collected: **Yes**'));

    expect(dataSafety, contains('Required or optional: **Optional**'));

    expect(dataSafety, contains('Purpose: **App functionality**'));

    expect(
      dataSafety,
      contains('Ephemeral processing: **No / do not select at this time**'),
    );

    expect(dataSafety, contains('**PENDING VERIFICATION**'));
  });

  test('data safety evidence does not claim unverified ZDR', () {
    final evidence = File('../docs/google-play-data-safety-evidence.md')
        .readAsStringSync();

    expect(evidence, contains('store=False'));

    expect(
      evidence,
      contains('MUST NOT be interpreted as proof of Zero Data Retention'),
    );

    expect(
      evidence,
      contains('Do not classify Recovery Companion AI processing as ephemeral'),
    );

    expect(
      evidence,
      contains('Sharing: pending provider/service-provider verification'),
    );
  });
}
