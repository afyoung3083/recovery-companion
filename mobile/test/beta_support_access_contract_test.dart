import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int occurrenceCount(String text, String pattern) {
  return RegExp(RegExp.escape(pattern)).allMatches(text).length;
}

void main() {
  test('Beta support is available throughout app navigation', () {
    final expectations = {
      'lib/main.dart': 3,
      'lib/dashboard_screen.dart': 1,
      'lib/more_screen.dart': 1,
      'lib/contact_profile_screen.dart': 1,
      'lib/initial_setup_screen.dart': 1,
      'lib/onboarding_screen.dart': 1,
    };

    for (final entry in expectations.entries) {
      final source = File(entry.key).readAsStringSync();

      expect(
        source,
        contains("import 'beta_support_action.dart';"),
        reason:
            '${entry.key} must import '
            'Beta support.',
      );

      expect(
        occurrenceCount(source, 'BetaSupportAction()'),
        greaterThanOrEqualTo(entry.value),
        reason:
            '${entry.key} must expose '
            'Beta support.',
      );
    }
  });

  test('Beta support links to guide and feedback', () {
    final source = File('lib/beta_support_action.dart').readAsStringSync();

    expect(source, contains('BetaTesterGuideScreen'));

    expect(source, contains('BetaFeedbackScreen'));

    expect(source, contains('Send Feedback'));

    expect(source, contains('Tester Guide'));
  });

  test('Goal target date is calendar controlled', () {
    final source = File('lib/goals_screen.dart').readAsStringSync();

    expect(source, contains('showDatePicker('));

    expect(source, contains('readOnly: true'));

    expect(source, contains('goals-clear-target-date'));

    expect(source, contains('goals-open-target-date-picker'));
  });
}
