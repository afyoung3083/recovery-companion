import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/mobile_config.dart';

void main() {
  test('production privacy policy has a stable public URL', () {
    expect(
      MobileConfig.privacyPolicyUrl,
      'https://afyoung3083.github.io/'
      'recovery-companion/privacy/',
    );

    expect(Uri.parse(MobileConfig.privacyPolicyUrl).scheme, 'https');
  });

  test('public privacy policy documents local and online processing', () {
    final policy = File('../docs/privacy/index.md').readAsStringSync();

    expect(policy, contains('Recovery information stored on your device'));

    expect(policy, contains('Information sent for optional online features'));

    expect(policy, contains('Data export and deletion'));

    expect(policy, contains('not a medical device'));

    expect(
      policy,
      contains('does not claim that optional online processing is ephemeral'),
    );
  });

  test('Play readiness references production privacy URL', () {
    final readiness = File('../docs/google-play-closed-beta-readiness.md')
        .readAsStringSync();

    expect(readiness, contains(MobileConfig.privacyPolicyUrl));

    expect(
      readiness,
      isNot(contains('**BLOCKER:** A public privacy-policy URL')),
    );
  });
}
