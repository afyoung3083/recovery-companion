import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/beta_feedback_screen.dart';
import 'package:mobile/mobile_config.dart';

void main() {
  test('beta support email is production support mailbox', () {
    expect(MobileConfig.supportEmail, 'support@recoverycompanionlabs.com');
  });

  test('email workflow preserves the complete report', () {
    const report = '''
Recovery Companion Beta Feedback

Type: Usability

What happened?
A tester observation.

---
Safe diagnostics.
''';

    final uri = buildBetaFeedbackEmailUri(report: report);

    expect(uri.queryParameters['body'], report);

    expect(uri.queryParameters['body'], contains('Safe diagnostics.'));
  });
}
