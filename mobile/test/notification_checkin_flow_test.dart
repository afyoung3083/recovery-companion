import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/beta_feedback_screen.dart';
import 'package:mobile/beta_tester_guide_screen.dart';
import 'package:mobile/daily_checkin_screen.dart';
import 'package:mobile/dashboard_screen.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/main.dart';
import 'package:mobile/reminder_scheduler.dart';
import 'package:mobile/secure_offline_cache_store.dart';
import 'package:mobile/weekly_review_screen.dart';

// No device keys, notification plugins, real recovery files, or live API calls.
class _UnusedKeyStore implements SecureKeyValueStore {
  @override
  Future<String?> read({required String key}) async =>
      throw StateError('Unexpected key access.');

  @override
  Future<Map<String, String>> readAll() async =>
      throw StateError('Unexpected key access.');

  @override
  Future<void> write({required String key, required String value}) async =>
      throw StateError('Unexpected key access.');

  @override
  Future<void> delete({required String key}) async =>
      throw StateError('Unexpected key access.');
}

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class _MemoryStore extends LocalRecoveryStore {
  _MemoryStore()
    : super(
        dataFile: File('NOT_USED_BY_THIS_TEST.enc'),
        keyStore: _UnusedKeyStore(),
      );

  Map<String, dynamic> data = {
    'profile': {'sobriety_date': '2025-01-01'},
    'unrelated_record': 'preserve-me',
  };
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? pendingRead;
  int writes = 0;

  @override
  Future<Map<String, dynamic>> read() async {
    final pending = pendingRead;
    if (pending != null) {
      await pending.future;
    }
    if (failRead) {
      throw StateError('Simulated unreadable storage.');
    }
    return {'schema_version': 1, 'data': _copy(data)};
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    if (failWrite) {
      throw StateError('Simulated save failure.');
    }
    this.data = _copy(data);
    writes++;
  }

  @override
  Future<void> deleteAll() async =>
      throw StateError('Recovery data must not be deleted by this flow.');
}

class _TestReminders extends ReminderScheduler {
  _TestReminders({required super.onNotificationTap, this.launchPayload});

  String? launchPayload;

  @override
  Future<void> initialize() async {}

  @override
  String? takeLaunchPayload() {
    final result = launchPayload;
    launchPayload = null;
    return result;
  }

  void tap(String payload) => onNotificationTap?.call(payload);
}

Future<_TestReminders> _mount(
  WidgetTester tester, {
  required Future<LocalRecoveryStore> Function() loader,
  String? launchPayload,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final requests = <String>[];
  final api = ApiClient(
    baseUrl: 'https://example.test',
    apiToken: 'test-only',
    httpClient: MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      return http.Response('{}', 500);
    }),
  );

  addTearDown(() {
    api.close();
    expect(
      requests,
      isEmpty,
      reason: 'Local check-in navigation must never fall back to the API.',
    );
  });

  late _TestReminders reminders;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: HomeShell(
        apiClient: api,
        localStoreLoader: loader,
        reminderFactory: (callback) {
          reminders = _TestReminders(
            onNotificationTap: callback,
            launchPayload: launchPayload,
          );
          return reminders;
        },
      ),
    ),
  );
  await tester.pump();
  return reminders;
}

Finder _dailyScrollable() => find
    .descendant(
      of: find.byType(DailyCheckInScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _fillCheckin(WidgetTester tester, String note) async {
  for (final key in [
    'daily-action-prayer',
    'daily-action-meeting',
    'daily-action-service',
  ]) {
    final tile = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      tile,
      250,
      scrollable: _dailyScrollable(),
    );
    await tester.tap(tile);
    await tester.pump();
  }

  final field = find.descendant(
    of: find.byType(DailyCheckInScreen),
    matching: find.byType(TextField),
  );
  await tester.scrollUntilVisible(
    field,
    250,
    scrollable: _dailyScrollable(),
  );
  await tester.enterText(field, note);
}

Future<void> _save(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('daily-checkin-save'));
  await tester.scrollUntilVisible(
    save,
    250,
    scrollable: _dailyScrollable(),
  );
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _checkDashboardAndReopen(
  WidgetTester tester,
  String expectedNote,
) async {
  await tester.pageBack();
  await tester.pumpAndSettle();

  final card = find.byKey(const ValueKey('dashboard-checkin'));
  final scrollable = find
      .descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  await tester.scrollUntilVisible(card, 250, scrollable: scrollable);
  expect(
    find.descendant(of: card, matching: find.text('3 of 6')),
    findsOneWidget,
  );

  await tester.tap(card);
  await tester.pumpAndSettle();

  for (final key in [
    'daily-action-prayer',
    'daily-action-meeting',
    'daily-action-service',
  ]) {
    final tile = find.byKey(ValueKey(key));
    final checkbox = find.descendant(
      of: tile,
      matching: find.byType(Checkbox),
    );
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
  }

  final field = find.descendant(
    of: find.byType(DailyCheckInScreen),
    matching: find.byType(TextField),
  );
  await tester.scrollUntilVisible(field, 250, scrollable: _dailyScrollable());
  expect(tester.widget<TextField>(field).controller!.text, expectedNote);
}

void main() {
  // Prove support remains reachable after replacing the duplicate route.
  for (final payload in ['daily_recovery', 'weekly_review']) {
    for (final coldLaunch in [true, false]) {
      testWidgets(
        'notification Beta support remains usable: '
        '$payload / ${coldLaunch ? "cold" : "warm"}',
        (tester) async {
          final store = _MemoryStore();
          final reminders = await _mount(
            tester,
            loader: () async => store,
            launchPayload: coldLaunch ? payload : null,
          );
          await tester.pumpAndSettle();

          if (!coldLaunch) {
            reminders.tap(payload);
            await tester.pumpAndSettle();
          }

          final screen = payload == 'daily_recovery'
              ? find.byType(DailyCheckInScreen)
              : find.byType(WeeklyReviewScreen);

          expect(screen, findsOneWidget);
          final originalState = tester.state(screen);
          final originalRoute = ModalRoute.of(tester.element(screen));

          const destinations = <String, Type>{
            'beta-support-tester-guide': BetaTesterGuideScreen,
            'beta-support-feedback': BetaFeedbackScreen,
          };

          for (final destination in destinations.entries) {
            final action = find.byKey(
              const ValueKey('beta-support-action'),
            );
            expect(action, findsOneWidget);
            await tester.tap(action);
            await tester.pumpAndSettle();

            final menuItem = find.byKey(ValueKey(destination.key));
            expect(menuItem, findsOneWidget);
            await tester.tap(menuItem);
            await tester.pumpAndSettle();

            // Opening the feedback form does not send feedback or email.
            expect(find.byType(destination.value), findsOneWidget);
            await tester.pageBack();
            await tester.pumpAndSettle();

            expect(screen, findsOneWidget);
            expect(tester.state(screen), same(originalState));
            expect(
              ModalRoute.of(tester.element(screen)),
              same(originalRoute),
            );
          }

          expect(store.writes, 0);
          expect(store.data['unrelated_record'], 'preserve-me');
        },
      );
    }
  }

  testWidgets('cold notification waits, saves locally, and reopens correctly', (
    tester,
  ) async {
    final store = _MemoryStore();
    final ready = Completer<LocalRecoveryStore>();

    await _mount(
      tester,
      loader: () => ready.future,
      launchPayload: 'daily_recovery',
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DailyCheckInScreen), findsNothing);
    expect(
      find.byKey(const ValueKey('local-recovery-startup-loading')),
      findsOneWidget,
    );

    ready.complete(store);
    await tester.pumpAndSettle();

    final screen = tester.widget<DailyCheckInScreen>(
      find.byType(DailyCheckInScreen),
    );
    expect(screen.localRepository!.store, same(store));

    const note = 'Fictional notification check-in.';
    await _fillCheckin(tester, note);
    await _save(tester);

    expect(store.writes, 1);
    final records = store.data['daily_checkins'] as Map;
    expect(records, hasLength(1));
    expect((records.values.single as Map)['note'], note);
    expect(store.data['unrelated_record'], 'preserve-me');

    await _checkDashboardAndReopen(tester, note);

    // A new widget instance reads a copy of the simulated saved document.
    // This is not a real disk-persistence or physical-device test.
    final reopened = _MemoryStore()..data = _copy(store.data);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _mount(
      tester,
      loader: () async => reopened,
      launchPayload: 'daily_recovery',
    );
    await tester.pumpAndSettle();
    await _checkDashboardAndReopen(tester, note);
    expect(reopened.writes, 0);
  });

  testWidgets('warm notification refreshes Dashboard and ignores duplicate taps', (
    tester,
  ) async {
    final store = _MemoryStore();
    final reminders = await _mount(tester, loader: () async => store);
    await tester.pumpAndSettle();

    final originalDashboard = tester.state(find.byType(DashboardScreen));
    reminders.tap('daily_recovery');
    reminders.tap('daily_recovery');
    await tester.pumpAndSettle();

    reminders.tap('daily_recovery');
    await tester.pumpAndSettle();
    expect(
      find.byType(DailyCheckInScreen, skipOffstage: false),
      findsOneWidget,
    );

    const note = 'Fictional warm-start check-in.';
    await _fillCheckin(tester, note);
    await _save(tester);
    await _checkDashboardAndReopen(tester, note);

    expect(
      tester.state(find.byType(DashboardScreen, skipOffstage: false)),
      same(originalDashboard),
    );
  });

  for (final failOpening in [true, false]) {
    testWidgets(
      'startup ${failOpening ? "open" : "read"} failure blocks forms and supports retry',
      (tester) async {
        final store = _MemoryStore();
        var fail = true;
        store.failRead = !failOpening;

        await _mount(
          tester,
          loader: () async {
            if (failOpening && fail) {
              throw StateError('Simulated open failure.');
            }
            return store;
          },
          launchPayload: 'daily_recovery',
        );
        await tester.pumpAndSettle();

        expect(find.byType(DailyCheckInScreen), findsNothing);
        expect(
          find.byKey(const ValueKey('local-recovery-startup-error')),
          findsOneWidget,
        );
        expect(store.writes, 0);

        fail = false;
        store.failRead = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        final screen = tester.widget<DailyCheckInScreen>(
          find.byType(DailyCheckInScreen),
        );
        expect(screen.localRepository!.store, same(store));
        expect(store.data['unrelated_record'], 'preserve-me');
      },
    );
  }

  testWidgets('failed local save keeps the draft and does not report success', (
    tester,
  ) async {
    final store = _MemoryStore()..failWrite = true;
    await _mount(
      tester,
      loader: () async => store,
      launchPayload: 'daily_recovery',
    );
    await tester.pumpAndSettle();

    const note = 'Keep this fictional draft after a failed save.';
    await _fillCheckin(tester, note);
    await _save(tester);

    expect(store.writes, 0);
    expect(store.data.containsKey('daily_checkins'), isFalse);
    expect(find.text('Daily check-in saved.'), findsNothing);

    final field = find.descendant(
      of: find.byType(DailyCheckInScreen),
      matching: find.byType(TextField),
    );
    await tester.scrollUntilVisible(
      field,
      -250,
      scrollable: _dailyScrollable(),
    );
    expect(tester.widget<TextField>(field).controller!.text, note);

    store.failWrite = false;
    await _save(tester);
    expect(store.writes, 1);
    await _checkDashboardAndReopen(tester, note);
  });

  testWidgets('weekly notification also waits for the shared local store', (
    tester,
  ) async {
    final ready = Completer<LocalRecoveryStore>();
    final store = _MemoryStore();

    await _mount(
      tester,
      loader: () => ready.future,
      launchPayload: 'weekly_review',
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(WeeklyReviewScreen), findsNothing);
    ready.complete(store);
    await tester.pumpAndSettle();

    final screen = tester.widget<WeeklyReviewScreen>(
      find.byType(WeeklyReviewScreen),
    );
    expect(screen.localRepository!.store, same(store));
  });

  testWidgets('closing during startup does not navigate after disposal', (
    tester,
  ) async {
    final ready = Completer<LocalRecoveryStore>();
    await _mount(
      tester,
      loader: () => ready.future,
      launchPayload: 'daily_recovery',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    ready.complete(_MemoryStore());
    await tester.pumpAndSettle();

    expect(find.byType(DailyCheckInScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification waits for the first document read to finish', (
    tester,
  ) async {
    final gate = Completer<void>();
    final store = _MemoryStore()..pendingRead = gate;
    final reminders = await _mount(
      tester,
      loader: () async => store,
      launchPayload: 'daily_recovery',
    );
    await tester.pump(const Duration(milliseconds: 100));
    reminders.tap('daily_recovery');
    await tester.pump();

    expect(find.byType(DailyCheckInScreen), findsNothing);
    expect(store.writes, 0);
    gate.complete();
    await tester.pumpAndSettle();

    expect(
      find.byType(DailyCheckInScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      tester.widget<DailyCheckInScreen>(find.byType(DailyCheckInScreen))
          .localRepository!.store,
      same(store),
    );
  });

  testWidgets('unknown notification payload leaves navigation unchanged', (
    tester,
  ) async {
    final store = _MemoryStore();
    final reminders = await _mount(tester, loader: () async => store);
    await tester.pumpAndSettle();
    final originalDashboard = tester.state(find.byType(DashboardScreen));

    reminders.tap('unknown-payload');
    await tester.pumpAndSettle();

    expect(find.byType(DailyCheckInScreen), findsNothing);
    expect(find.byType(WeeklyReviewScreen), findsNothing);
    expect(tester.state(find.byType(DashboardScreen)), same(originalDashboard));
    expect(store.writes, 0);
  });
}
