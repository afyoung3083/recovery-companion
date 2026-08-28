import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/first_use_guidance.dart';

void main() {
  testWidgets('first-use guidance renders orientation and actions', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstUseGuidanceCard(
            title: 'Start here',
            message: 'Take one useful recovery action.',
            actions: [
              FirstUseGuidanceAction(
                label: 'Daily Recovery',
                icon: Icons.check_circle_outline,
                onTap: () {
                  tapped = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Start here'), findsOneWidget);

    expect(find.text('Take one useful recovery action.'), findsOneWidget);

    expect(find.text('Daily Recovery'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('first-use-action-0')));

    expect(tapped, isTrue);
  });

  testWidgets('first-use guidance handles several actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstUseGuidanceCard(
            title: 'New here?',
            message: 'Choose a next step.',
            actions: [
              FirstUseGuidanceAction(
                label: 'One',
                icon: Icons.looks_one,
                onTap: () {},
              ),
              FirstUseGuidanceAction(
                label: 'Two',
                icon: Icons.looks_two,
                onTap: () {},
              ),
              FirstUseGuidanceAction(
                label: 'Three',
                icon: Icons.looks_3,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsNWidgets(3));
  });
}
