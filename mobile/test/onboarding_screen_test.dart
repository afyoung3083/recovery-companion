import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/onboarding_screen.dart';

void main() {
  testWidgets('onboarding explains privacy and completes', (tester) async {
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onComplete: () async {
            completed = true;
          },
        ),
      ),
    );

    expect(find.text('Recovery support for real life'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));

    await tester.pumpAndSettle();

    expect(find.text('Your recovery data stays with you'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));

    await tester.pumpAndSettle();

    expect(find.text('You control what AI sees'), findsOneWidget);

    final aiPageText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join();

    expect(aiPageText, contains('request\u2014not'));
    expect(aiPageText, isNot(contains('request?not')));

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));

    await tester.pumpAndSettle();

    expect(find.text('Start with today'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));

    await tester.pump();

    expect(completed, isTrue);
  });
}
