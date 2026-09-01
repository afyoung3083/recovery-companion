import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/beta_feedback_screen.dart';
import 'package:mobile/beta_support_action.dart';
import 'package:mobile/beta_tester_guide_screen.dart';

Widget buildHost() {
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Test'),
        actions: const [BetaSupportAction()],
      ),
      body: const Center(child: Text('Host screen')),
    ),
  );
}

void main() {
  testWidgets('Beta menu opens the tester guide', (tester) async {
    await tester.pumpWidget(buildHost());

    await tester.tap(find.byKey(const ValueKey('beta-support-action')));

    await tester.pumpAndSettle();

    expect(find.text('Tester Guide'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('beta-support-tester-guide')));

    await tester.pumpAndSettle();

    expect(find.byType(BetaTesterGuideScreen), findsOneWidget);
  });

  testWidgets('Beta menu opens feedback and support', (tester) async {
    await tester.pumpWidget(buildHost());

    await tester.tap(find.byKey(const ValueKey('beta-support-action')));

    await tester.pumpAndSettle();

    expect(find.text('Send Feedback'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('beta-support-feedback')));

    await tester.pumpAndSettle();

    expect(find.byType(BetaFeedbackScreen), findsOneWidget);
  });
}
