import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets(
    'Recovery Companion shell loads',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const RecoveryCompanionApp(),
      );

      expect(
        find.text('Recovery Companion'),
        findsOneWidget,
      );

      expect(
        find.text('Dashboard'),
        findsWidgets,
      );

      expect(
        find.text('Insights'),
        findsOneWidget,
      );

      expect(
        find.text('Goals'),
        findsOneWidget,
      );

      expect(
        find.text('Routines'),
        findsOneWidget,
      );

      expect(
        find.text('More'),
        findsOneWidget,
      );
    },
  );
}