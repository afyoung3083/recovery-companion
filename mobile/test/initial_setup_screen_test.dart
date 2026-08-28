import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/initial_setup_screen.dart';
import 'package:mobile/initial_setup_service.dart';

void main() {
  testWidgets('guided setup can be skipped immediately', (tester) async {
    var skipped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: InitialSetupScreen(
          onFinish: (_) async {},
          onSkip: () async {
            skipped = true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('initial-setup-skip')));

    await tester.pump();

    expect(skipped, isTrue);
  });

  testWidgets('guided setup captures goal routine and reminder preferences', (
    tester,
  ) async {
    InitialSetupDraft? result;

    await tester.pumpWidget(
      MaterialApp(
        home: InitialSetupScreen(
          onFinish: (draft) async {
            result = draft;
          },
          onSkip: () async {},
        ),
      ),
    );

    // Sobriety-date page: leave blank.
    await tester.tap(find.byKey(const ValueKey('initial-setup-next')));
    await tester.pumpAndSettle();

    // Goal page.
    await tester.enterText(
      find.byKey(const ValueKey('initial-goal-field')),
      'Stay connected',
    );

    await tester.tap(find.byKey(const ValueKey('initial-setup-next')));
    await tester.pumpAndSettle();

    // Routine page.
    await tester.enterText(
      find.byKey(const ValueKey('initial-routine-field')),
      'Morning prayer',
    );

    await tester.tap(find.byKey(const ValueKey('initial-setup-next')));
    await tester.pumpAndSettle();

    // Reminder page.
    await tester.tap(find.byKey(const ValueKey('initial-daily-reminder')));

    final descriptiveSwitch = find.byKey(
      const ValueKey('initial-descriptive-notifications'),
    );

    // The privacy switch is below the visible test viewport.
    // Scroll its enclosing setup page until it can actually receive taps.
    await tester.ensureVisible(descriptiveSwitch);
    await tester.pumpAndSettle();

    await tester.tap(descriptiveSwitch);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('initial-setup-next')));

    await tester.pump();

    expect(result, isNotNull);
    expect(result?.goalText, 'Stay connected');
    expect(result?.routineText, 'Morning prayer');
    expect(result?.dailyReminderEnabled, isTrue);
    expect(result?.weeklyReminderEnabled, isFalse);
    expect(result?.descriptiveNotifications, isTrue);
  });

  testWidgets('failed setup save stays recoverable', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: InitialSetupScreen(
          onFinish: (_) async {
            attempts++;
            throw StateError('simulated failure');
          },
          onSkip: () async {},
        ),
      ),
    );

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(const ValueKey('initial-setup-next')));

      await tester.pumpAndSettle();
    }

    expect(attempts, 1);

    expect(
      find.byKey(const ValueKey('initial-setup-save-error')),
      findsOneWidget,
    );

    expect(find.textContaining('You can retry or skip setup'), findsOneWidget);
  });
}
