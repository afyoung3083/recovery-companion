import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app_theme.dart';
import 'package:mobile/reminder_preferences.dart';
import 'package:mobile/reminder_scheduler.dart';
import 'package:mobile/reminders_screen.dart';

class FakeReminderStorage implements ReminderPreferencesStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String newValue) async {
    value = newValue;
  }
}

class FakeReminderScheduler implements ReminderSchedulingService {
  bool permissionGranted = true;
  int permissionRequests = 0;
  final List<ReminderPreferences> applied = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return permissionGranted;
  }

  @override
  Future<void> apply(ReminderPreferences preferences) async {
    applied.add(preferences);
  }
}

Future<void> pumpReminders(
  WidgetTester tester, {
  required ReminderPreferencesRepository repository,
  required ReminderSchedulingService scheduler,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RemindersScreen(repository: repository, scheduler: scheduler),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> scrollDownTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();
}

Future<void> scrollUpTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    -300,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Reminders start disabled and private', (tester) async {
    final storage = FakeReminderStorage();

    await pumpReminders(
      tester,
      repository: ReminderPreferencesRepository(storage: storage),
      scheduler: FakeReminderScheduler(),
    );

    final daily = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('daily-reminder-switch')),
    );

    expect(daily.value, false);

    final weeklyFinder = find.byKey(const ValueKey('weekly-reminder-switch'));

    await scrollDownTo(tester, weeklyFinder);

    final weekly = tester.widget<SwitchListTile>(weeklyFinder);

    expect(weekly.value, false);

    final privacyFinder = find.byKey(
      const ValueKey('descriptive-notification-switch'),
    );

    await scrollDownTo(tester, privacyFinder);

    final privacy = tester.widget<SwitchListTile>(privacyFinder);

    expect(privacy.value, false);

    expect(find.text('A reminder you asked for is ready.'), findsOneWidget);
  });

  testWidgets('Enabling a reminder asks permission and saves', (tester) async {
    final storage = FakeReminderStorage();
    final scheduler = FakeReminderScheduler();

    final repository = ReminderPreferencesRepository(storage: storage);

    await pumpReminders(tester, repository: repository, scheduler: scheduler);

    await tester.tap(find.byKey(const ValueKey('daily-reminder-switch')));

    await tester.pumpAndSettle();

    final saveFinder = find.byKey(const ValueKey('save-reminders'));

    await scrollDownTo(tester, saveFinder);

    await tester.tap(saveFinder);
    await tester.pumpAndSettle();

    final saved = await repository.load();

    expect(scheduler.permissionRequests, 1);

    expect(scheduler.applied, hasLength(1));

    expect(saved.dailyRecoveryEnabled, true);

    final successFinder = find.text('Reminder settings saved on this device.');

    await scrollUpTo(tester, successFinder);

    expect(successFinder, findsOneWidget);
  });

  testWidgets('Denied permission does not save enabled reminder', (
    tester,
  ) async {
    final storage = FakeReminderStorage();

    final scheduler = FakeReminderScheduler()..permissionGranted = false;

    final repository = ReminderPreferencesRepository(storage: storage);

    await pumpReminders(tester, repository: repository, scheduler: scheduler);

    await tester.tap(find.byKey(const ValueKey('daily-reminder-switch')));

    await tester.pumpAndSettle();

    final saveFinder = find.byKey(const ValueKey('save-reminders'));

    await scrollDownTo(tester, saveFinder);

    await tester.tap(saveFinder);
    await tester.pumpAndSettle();

    final saved = await repository.load();

    expect(scheduler.permissionRequests, 1);

    expect(saved.dailyRecoveryEnabled, false);

    expect(scheduler.applied, isEmpty);

    final unchangedFinder = find.text('Reminder settings unchanged');

    await scrollUpTo(tester, unchangedFinder);

    expect(unchangedFinder, findsOneWidget);
  });
}
