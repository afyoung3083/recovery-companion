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

  test('More exposes beta feedback through centralized support navigation', () {
    final more = File('lib/more_screen.dart').readAsStringSync();

    expect(more, contains("title: 'Beta Feedback & Support'"));

    expect(more, contains('openBetaSupportDestination('));

    expect(more, contains('BetaSupportDestination.feedback'));

    expect(more, contains("import 'beta_support_action.dart';"));
  });

  test('central Beta support navigation owns feedback screen', () {
    final support = File('lib/beta_support_action.dart').readAsStringSync();

    expect(support, contains("import 'beta_feedback_screen.dart';"));

    expect(support, contains('BetaFeedbackScreen()'));

    expect(support, contains('BetaSupportDestination.feedback'));

    expect(support, contains("'Send Feedback'"));
  });
}
