import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/daily_checkin_screen.dart';
import 'package:mobile/journal_screen.dart';
import 'package:mobile/offline_read_service.dart';

Future<void> scrollDownUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 15; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));

    await tester.pumpAndSettle();
  }

  throw TestFailure('Expected widget did not become visible.');
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('Daily Recovery uses only todays cached check-in', (
    tester,
  ) async {
    final cache = MemoryOfflineCacheStore();

    final today = DateTime(2026, 8, 25, 10);

    await cache.write(
      OfflineCacheKeys.dailyCheckin(today),
      OfflineCacheEntry(
        data: {
          'date': '2026-08-25',
          'checkin': {
            'date': '2026-08-25',
            'prayer_meditation': true,
            'recovery_contact': false,
            'meeting': true,
            'step_work': false,
            'journal': true,
            'service': false,
            'note': 'Cached daily note.',
          },
        },
        cachedAt: DateTime.utc(2026, 8, 25, 13),
      ),
    );

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((request) async {
        throw http.ClientException('Offline');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DailyCheckInScreen(
            apiClient: apiClient,
            offlineReadService: OfflineReadService(cache: cache),
            now: () => today,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Offline copy'), findsOneWidget);

    expect(find.textContaining('most recent encrypted copy'), findsOneWidget);

    final firstCheckbox = tester.widget<Checkbox>(find.byType(Checkbox).first);

    expect(firstCheckbox.value, true);

    apiClient.close();
  });

  testWidgets('Daily Recovery never uses a previous-day cache as today', (
    tester,
  ) async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      OfflineCacheKeys.dailyCheckin(DateTime(2026, 8, 24)),
      OfflineCacheEntry(
        data: {
          'date': '2026-08-24',
          'checkin': {'prayer_meditation': true},
        },
        cachedAt: DateTime.utc(2026, 8, 24),
      ),
    );

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((request) async {
        throw http.ClientException('Offline');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DailyCheckInScreen(
            apiClient: apiClient,
            offlineReadService: OfflineReadService(cache: cache),
            now: () => DateTime(2026, 8, 25, 9),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily check-in unavailable'), findsOneWidget);

    expect(find.text('Offline copy'), findsNothing);

    apiClient.close();
  });

  testWidgets('Journal history remains readable offline', (tester) async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      OfflineCacheKeys.journal,
      OfflineCacheEntry(
        data: {
          'count': 1,
          'entries': [
            {
              'id': 7,
              'created_at': '2026-08-22T20:00:00',
              'text': 'Cached journal reflection.',
              'tags': ['connection'],
            },
          ],
        },
        cachedAt: DateTime.utc(2026, 8, 25, 13),
      ),
    );

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((request) async {
        throw http.ClientException('Offline');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: JournalScreen(
            apiClient: apiClient,
            offlineReadService: OfflineReadService(cache: cache),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final searchFinder = find.widgetWithText(OutlinedButton, 'Search');

    await scrollDownUntilVisible(tester, searchFinder);

    final searchButton = tester.widget<OutlinedButton>(searchFinder);

    expect(searchButton.onPressed, isNull);

    final offlineFinder = find.text('Offline copy');

    await scrollDownUntilVisible(tester, offlineFinder);

    expect(offlineFinder, findsOneWidget);

    final entryFinder = find.text('Cached journal reflection.');

    await scrollDownUntilVisible(tester, entryFinder);

    expect(entryFinder, findsOneWidget);

    final analyzeFinder = find.byKey(const ValueKey('journal-ai-7'));

    await scrollDownUntilVisible(tester, analyzeFinder);

    final analyzeButton = tester.widget<OutlinedButton>(analyzeFinder);

    expect(analyzeButton.onPressed, isNull);

    apiClient.close();
  });

  testWidgets('Journal cache is not exposed after auth failure', (
    tester,
  ) async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      OfflineCacheKeys.journal,
      OfflineCacheEntry(
        data: {
          'count': 1,
          'entries': [
            {'id': 7, 'text': 'Private cached entry.', 'tags': []},
          ],
        },
        cachedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((request) async {
        return http.Response(jsonEncode({}), 401);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: JournalScreen(
            apiClient: apiClient,
            offlineReadService: OfflineReadService(cache: cache),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final unavailableFinder = find.text('Unable to load journal');

    await scrollDownUntilVisible(tester, unavailableFinder);

    expect(unavailableFinder, findsOneWidget);

    expect(find.text('Offline copy'), findsNothing);

    expect(find.text('Private cached entry.'), findsNothing);

    apiClient.close();
  });
}
