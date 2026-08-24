import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/insights_screen.dart';

Map<String, dynamic> insightsResponse() {
  return {
    'recovery_insights':
        'Recovery Insights\n'
        'Current Step: 4\n'
        'Active Recovery Goals: 2',
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

Future<void> scrollDownUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -350));

    await tester.pumpAndSettle();
  }

  throw TestFailure('Expected Insights widget did not become visible.');
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets(
    'Recovery Insights AI requires confirmation and shows reflection',
    (tester) async {
      var aiRequestCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/recovery-insights') {
          return http.Response(jsonEncode(insightsResponse()), 200);
        }

        if (request.method == 'POST' &&
            request.url.path == '/recovery-insights/ai-reflection') {
          aiRequestCount += 1;

          expect(request.headers['Authorization'], 'Bearer $token');

          expect(request.body, isEmpty);

          return http.Response(
            jsonEncode({
              'reflection':
                  'Human connection may be worth continuing to prioritize.',
            }),
            200,
          );
        }

        throw StateError(
          'Unexpected request: '
          '${request.method} ${request.url}',
        );
      });

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: InsightsScreen(apiClient: apiClient)),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('recovery-insights-summary')),
        findsOneWidget,
      );

      expect(find.text('Step 4'), findsOneWidget);

      expect(find.text('2 active'), findsOneWidget);

      expect(find.text('5 of 7'), findsOneWidget);

      final analyzeButton = find.byKey(const ValueKey('recovery-insights-ai'));

      await scrollDownUntilBuilt(tester, analyzeButton);

      await tester.tap(analyzeButton);

      await tester.pumpAndSettle();

      expect(aiRequestCount, 0);

      expect(find.text('Analyze Recovery Insights?'), findsOneWidget);

      expect(
        find.text(
          'Recovery Companion will build your current Recovery '
          'Insights summary locally and send only that summary to '
          'the AI for an optional reflection. The summary contains '
          'dashboard counts and recovery status, not raw journal '
          'entries or check-in notes. The AI reflection is not '
          'saved automatically.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Analyze Insights'));

      await tester.pumpAndSettle();

      expect(aiRequestCount, 1);

      final reflection = find.byKey(
        const ValueKey('recovery-insights-ai-reflection'),
      );

      await scrollDownUntilBuilt(tester, reflection);

      expect(reflection, findsOneWidget);

      expect(
        find.text('Human connection may be worth continuing to prioritize.'),
        findsOneWidget,
      );

      apiClient.close();
    },
  );

  testWidgets('cancelling Recovery Insights AI sends nothing', (tester) async {
    var aiRequestCount = 0;

    final mockClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/recovery-insights') {
        return http.Response(jsonEncode(insightsResponse()), 200);
      }

      if (request.method == 'POST' &&
          request.url.path == '/recovery-insights/ai-reflection') {
        aiRequestCount += 1;

        return http.Response(
          jsonEncode({'reflection': 'This should not be requested.'}),
          200,
        );
      }

      throw StateError(
        'Unexpected request: '
        '${request.method} ${request.url}',
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: InsightsScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    final analyzeButton = find.byKey(const ValueKey('recovery-insights-ai'));

    await scrollDownUntilBuilt(tester, analyzeButton);

    await tester.tap(analyzeButton);

    await tester.pumpAndSettle();

    expect(aiRequestCount, 0);

    await tester.tap(find.text('Cancel'));

    await tester.pumpAndSettle();

    expect(aiRequestCount, 0);

    apiClient.close();
  });
}
