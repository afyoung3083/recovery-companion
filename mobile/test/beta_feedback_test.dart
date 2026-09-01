import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/beta_feedback_screen.dart';
import 'package:mobile/mobile_config.dart';

void main() {
  test('beta diagnostics contain safe build context', () {
    final diagnostics = buildBetaDiagnostics(
      platform: 'Android',
      buildMode: 'debug',
    );

    expect(diagnostics, contains(MobileConfig.betaBuildLabel));

    expect(diagnostics, contains('Platform: Android'));

    expect(diagnostics, contains('Build mode: debug'));

    expect(diagnostics, contains('does not include recovery records'));

    expect(diagnostics.toLowerCase(), isNot(contains('api token:')));
  });

  test('beta report preserves tester observations', () {
    final report = buildBetaFeedbackReport(
      feedbackType: 'Bug',
      summary: 'Save did nothing',
      expected: 'Entry should appear',
      steps: 'Open Journal, save',
      diagnostics: 'safe diagnostics',
    );

    expect(report, contains('Type: Bug'));

    expect(report, contains('Save did nothing'));

    expect(report, contains('Entry should appear'));

    expect(report, contains('Open Journal, save'));

    expect(report, contains('safe diagnostics'));
  });

  test('beta feedback email targets support mailbox', () {
    final uri = buildBetaFeedbackEmailUri(report: 'SAFE BETA REPORT');

    expect(uri.scheme, 'mailto');

    expect(uri.path, MobileConfig.supportEmail);

    expect(
      uri.queryParameters['subject'],
      contains('Recovery Companion Beta Feedback'),
    );

    expect(
      uri.queryParameters['subject'],
      contains(MobileConfig.betaBuildLabel),
    );

    expect(uri.queryParameters['body'], 'SAFE BETA REPORT');
  });

  testWidgets('beta feedback screen exposes feedback and diagnostic controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BetaFeedbackScreen())),
    );

    expect(find.byKey(const ValueKey('beta-feedback-summary')), findsOneWidget);

    expect(
      find.byKey(const ValueKey('beta-feedback-expected')),
      findsOneWidget,
    );

    final diagnosticsButton = find.byKey(
      const ValueKey('copy-beta-diagnostics'),
    );

    await tester.scrollUntilVisible(
      diagnosticsButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(diagnosticsButton, findsOneWidget);

    final sendButton = find.byKey(const ValueKey('send-beta-feedback'));

    await tester.scrollUntilVisible(
      sendButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(sendButton, findsOneWidget);

    expect(find.text('Send Feedback'), findsOneWidget);

    final reportButton = find.byKey(const ValueKey('copy-beta-report'));

    await tester.scrollUntilVisible(
      reportButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(reportButton, findsOneWidget);
  });
}
