import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/privacy_health_info_screen.dart';

void main() {
  testWidgets('privacy and health information states core safeguards', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PrivacyHealthInfoScreen())),
    );

    expect(find.text('Privacy & Health Information'), findsOneWidget);

    expect(find.text('Not a medical device'), findsOneWidget);

    expect(find.text('Not an emergency service'), findsOneWidget);

    final storedLocally = find.text('Stored on your device');

    await tester.scrollUntilVisible(
      storedLocally,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(storedLocally, findsOneWidget);

    final aiWarning = find.text('AI can be wrong');

    await tester.scrollUntilVisible(
      aiWarning,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(aiWarning, findsOneWidget);
  });
}
