import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/beta_tester_guide_screen.dart';

void main() {
  testWidgets('closed beta tester guide teaches safe useful testing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BetaTesterGuideScreen())),
    );

    expect(find.text('Closed Beta Tester Guide'), findsOneWidget);

    expect(find.text('Beta software'), findsOneWidget);

    final privacy = find.text('Protect your privacy');

    await tester.scrollUntilVisible(
      privacy,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(privacy, findsOneWidget);

    final feedback = find.text('Useful feedback');

    await tester.scrollUntilVisible(
      feedback,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(feedback, findsOneWidget);
  });
}
