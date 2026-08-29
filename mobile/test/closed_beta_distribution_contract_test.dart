import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closed beta onboarding protects private recovery content', () {
    final guide = File('../docs/closed-beta-tester-onboarding.md')
        .readAsStringSync();

    expect(
      guide,
      contains('Do not ask testers to provide sensitive recovery information'),
    );

    expect(guide, contains('Google Play closed-testing flow'));

    expect(guide, contains('local records survive'));

    expect(guide, contains('security/privacy'));
  });
}
