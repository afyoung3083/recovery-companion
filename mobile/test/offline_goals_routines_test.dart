import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/goals_screen.dart';
import 'package:mobile/offline_read_service.dart';
import 'package:mobile/routines_screen.dart';

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('Goals remain readable but not editable offline', (tester) async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      OfflineCacheKeys.goals,
      OfflineCacheEntry(
        data: {
          'goals': [
            {
              'id': 5,
              'text': 'Call sponsor twice this week',
              'area': 'connection',
              'target_date': '2026-08-30',
            },
          ],
        },
        cachedAt: DateTime.utc(2026, 8, 26),
      ),
    );

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async {
        throw http.ClientException('Offline');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: GoalsScreen(
            apiClient: apiClient,
            offlineReadService: OfflineReadService(cache: cache),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final offline = find.text('Offline copy');
    await scrollTo(tester, offline);

    expect(offline, findsOneWidget);
    expect(find.text('Call sponsor twice this week'), findsOneWidget);

    final complete = find.widgetWithText(FilledButton, 'Complete');

    await scrollTo(tester, complete);

    expect(tester.widget<FilledButton>(complete).onPressed, isNull);

    apiClient.close();
  });

  testWidgets('Routines remain readable but not editable offline', (
    tester,
  ) async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      OfflineCacheKeys.routines,
      OfflineCacheEntry(
        data: {
          'routines': [
            {
              'id': 8,
              'text': 'Morning prayer',
              'area': 'prayer',
              'frequency': 'daily',
              'day_of_week': '',
            },
          ],
        },
        cachedAt: DateTime.utc(2026, 8, 26),
      ),
    );

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async {
        throw http.ClientException('Offline');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoutinesScreen(
            apiClient: apiClient,
            offlineReadService: OfflineReadService(cache: cache),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final offline = find.text('Offline copy');
    await scrollTo(tester, offline);

    expect(offline, findsOneWidget);
    expect(find.text('Morning prayer'), findsOneWidget);

    final routineSwitch = find.byType(Switch).last;

    await scrollTo(tester, routineSwitch);

    expect(tester.widget<Switch>(routineSwitch).onChanged, isNull);

    apiClient.close();
  });

  testWidgets('Goals cache is not exposed after auth failure', (tester) async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      OfflineCacheKeys.goals,
      OfflineCacheEntry(
        data: {
          'goals': [
            {'id': 5, 'text': 'Private cached goal'},
          ],
        },
        cachedAt: DateTime.utc(2026, 8, 26),
      ),
    );

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async {
        return http.Response(jsonEncode({}), 401);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: GoalsScreen(
            apiClient: apiClient,
            offlineReadService: OfflineReadService(cache: cache),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final unavailable = find.text('Unable to load goals');

    await scrollTo(tester, unavailable);

    expect(unavailable, findsOneWidget);
    expect(find.text('Offline copy'), findsNothing);
    expect(find.text('Private cached goal'), findsNothing);

    apiClient.close();
  });

  testWidgets('Routines cache is not exposed after auth failure', (
    tester,
  ) async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      OfflineCacheKeys.routines,
      OfflineCacheEntry(
        data: {
          'routines': [
            {'id': 8, 'text': 'Private routine'},
          ],
        },
        cachedAt: DateTime.utc(2026, 8, 26),
      ),
    );

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async {
        return http.Response(jsonEncode({}), 403);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoutinesScreen(
            apiClient: apiClient,
            offlineReadService: OfflineReadService(cache: cache),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final unavailable = find.text('Unable to load routines');

    await scrollTo(tester, unavailable);

    expect(unavailable, findsOneWidget);
    expect(find.text('Offline copy'), findsNothing);
    expect(find.text('Private routine'), findsNothing);

    apiClient.close();
  });
}
