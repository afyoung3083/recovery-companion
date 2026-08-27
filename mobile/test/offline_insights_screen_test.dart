import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/insights_screen.dart';
import 'package:mobile/offline_read_service.dart';

Map<String, dynamic> insightsResponse() {
  return {
    'recovery_insights_data': {
      'sobriety_date': '2025-08-10',
      'sobriety_days': 378,
      'current_step': 4,
      'open_step_assignments': 1,
      'active_recovery_goals': 2,
      'checkin_days_available': 5,
      'checkin_window_days': 7,
      'latest_weekly_snapshot': {
        'week_start': '2026-08-17',
        'week_end': '2026-08-23',
        'checkin_days': 5,
        'journal_entries': 3,
      },
      'latest_monthly_snapshot': {
        'snapshot_date': '2026-08-23',
        'period_start': '2026-07-27',
        'period_end': '2026-08-23',
        'weekly_reviews_included': 4,
        'checkin_days': 20,
        'journal_entries': 10,
      },
    },
  };
}

Widget appFor(
  ApiClient apiClient, {
  required OfflineReadService offlineReadService,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: InsightsScreen(
        apiClient: apiClient,
        offlineReadService: offlineReadService,
      ),
    ),
  );
}

Future<void> scrollDownUntilBuilt(
  WidgetTester tester,
  Finder finder,
) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -350),
    );

    await tester.pumpAndSettle();
  }

  throw TestFailure(
    'Expected Insights widget did not become visible.',
  );
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';
  const cacheKey = 'insights';

  testWidgets(
    'Online Insights response is cached for offline use',
    (tester) async {
      final cache = MemoryOfflineCacheStore();

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/recovery-insights',
          );

          return http.Response(
            jsonEncode(insightsResponse()),
            200,
          );
        }),
      );

      final service = OfflineReadService(
        cache: cache,
        clock: () => DateTime.utc(
          2026,
          8,
          27,
          14,
        ),
      );

      await tester.pumpWidget(
        appFor(
          apiClient,
          offlineReadService: service,
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'recovery-insights-summary',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.text('Step 4'),
        findsOneWidget,
      );

      expect(
        find.text('Offline copy'),
        findsNothing,
      );

      final cached =
          await cache.read(cacheKey);

      expect(cached, isNotNull);

      expect(
        cached!.cachedAt,
        DateTime.utc(
          2026,
          8,
          27,
          14,
        ),
      );

      expect(
        cached.data[
            'recovery_insights_data'],
        insightsResponse()[
            'recovery_insights_data'],
      );

      apiClient.close();
    },
  );

  testWidgets(
    'Insights remains readable offline and AI is disabled',
    (tester) async {
      final cache = MemoryOfflineCacheStore();

      await cache.write(
        cacheKey,
        OfflineCacheEntry(
          data: insightsResponse(),
          cachedAt: DateTime.utc(
            2026,
            8,
            27,
            13,
            30,
          ),
        ),
      );

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: MockClient(
          (request) async {
            throw http.ClientException(
              'Device is offline',
            );
          },
        ),
      );

      final service = OfflineReadService(
        cache: cache,
      );

      await tester.pumpWidget(
        appFor(
          apiClient,
          offlineReadService: service,
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Offline copy'),
        findsOneWidget,
      );

      expect(
        find.textContaining(
          'most recent encrypted copy',
        ),
        findsOneWidget,
      );

      expect(
        find.text('Step 4'),
        findsOneWidget,
      );

      expect(
        find.text('2 active'),
        findsOneWidget,
      );

      expect(
        find.text('5 of 7'),
        findsOneWidget,
      );

      final analyzeButton =
          find.byKey(
        const ValueKey(
          'recovery-insights-ai',
        ),
      );

      await scrollDownUntilBuilt(
        tester,
        analyzeButton,
      );

      final button =
          tester.widget<OutlinedButton>(
        analyzeButton,
      );

      expect(
        button.onPressed,
        isNull,
      );

      apiClient.close();
    },
  );

  testWidgets(
    'Insights never exposes cached data after auth failure',
    (tester) async {
      final cache = MemoryOfflineCacheStore();

      await cache.write(
        cacheKey,
        OfflineCacheEntry(
          data: insightsResponse(),
          cachedAt: DateTime.utc(
            2026,
            8,
            27,
          ),
        ),
      );

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: MockClient(
          (request) async {
            return http.Response(
              jsonEncode({}),
              401,
            );
          },
        ),
      );

      final service = OfflineReadService(
        cache: cache,
      );

      await tester.pumpWidget(
        appFor(
          apiClient,
          offlineReadService: service,
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'Unable to load Recovery Insights',
        ),
        findsOneWidget,
      );

      expect(
        find.text('Offline copy'),
        findsNothing,
      );

      expect(
        find.text('Step 4'),
        findsNothing,
      );

      expect(
        find.text('378 days'),
        findsNothing,
      );

      expect(
        find.byKey(
          const ValueKey(
            'recovery-insights-summary',
          ),
        ),
        findsNothing,
      );

      apiClient.close();
    },
  );
}
