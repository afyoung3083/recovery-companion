import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beta diagnostic version stays synchronized with pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final config = File('lib/mobile_config.dart').readAsStringSync();

    final versionMatch = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(versionMatch, isNotNull);

    final version = versionMatch!.group(1)!;

    expect(config, contains("betaBuildLabel = '$version'"));
  });

  test('More exposes beta feedback entry point', () {
    final more = File('lib/more_screen.dart').readAsStringSync();

    expect(more, contains("title: 'Beta Feedback & Support'"));

    expect(more, contains('BetaFeedbackScreen'));
  });
}
