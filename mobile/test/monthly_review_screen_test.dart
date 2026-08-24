import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/monthly_review_screen.dart';

Future<void> scrollUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 14; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));

    await tester.pumpAndSettle();
  }

  throw TestFailure('Expected Monthly Review widget did not become visible.');
}

http.Response responseForGet(http.Request request) {
  switch (request.url.path) {
    case '/monthly-review/current':
      return http.Response(
        jsonEncode({
          'review': 'Monthly Recovery Review\nWeekly Reviews Included: 4/4',
        }),
        200,
      );

    case '/monthly-review/history':
      return http.Response(
        jsonEncode({
          'history': [
            {
              'snapshot_date': '2026-07-24',
              'period_start': '2026-06-27',
              'period_end': '2026-07-24',
              'weekly_reviews_included': 4,
              'checkin_days': 19,
              'journal_entries': 8,
            },
            {
              'snapshot_date': '2026-08-24',
              'period_start': '2026-07-28',
              'period_end': '2026-08-24',
              'weekly_reviews_included': 4,
              'checkin_days': 21,
              'journal_entries': 10,
            },
          ],
        }),
        200,
      );

    case '/monthly-review/comparison':
      return http.Response(
        jsonEncode({'comparison': 'Check-In Days: 19 -> 21'}),
        200,
      );
  }

  throw StateError('Unexpected GET: ${request.url}');
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('Monthly Review renders review history and comparison', (
    tester,
  ) async {
    final mockClient = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer $token');

      if (request.method == 'GET') {
        return responseForGet(request);
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
        home: Scaffold(body: MonthlyReviewScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('monthly-review-screen')), findsOneWidget);

    expect(find.textContaining('Monthly Recovery Review'), findsOneWidget);

    await scrollUntilBuilt(tester, find.text('Snapshot 2026-08-24'));

    expect(find.text('Snapshot 2026-08-24'), findsOneWidget);

    await scrollUntilBuilt(
      tester,
      find.textContaining('Check-In Days: 19 -> 21'),
    );

    expect(find.textContaining('Check-In Days: 19 -> 21'), findsOneWidget);

    apiClient.close();
  });

  testWidgets('Monthly Review saves a snapshot', (tester) async {
    var snapshotSaved = false;

    final mockClient = MockClient((request) async {
      if (request.method == 'GET') {
        return responseForGet(request);
      }

      if (request.method == 'POST' &&
          request.url.path == '/monthly-review/snapshot') {
        snapshotSaved = true;

        return http.Response(
          jsonEncode({
            'snapshot': {'snapshot_date': '2026-08-24'},
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
        home: Scaffold(body: MonthlyReviewScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('monthly-review-save')));

    await tester.pumpAndSettle();

    expect(snapshotSaved, isTrue);

    expect(find.text('Monthly review saved.'), findsOneWidget);

    apiClient.close();
  });

  testWidgets('Monthly Review AI reflection runs only when requested', (
    tester,
  ) async {
    var reflectionRequested = false;

    final mockClient = MockClient((request) async {
      if (request.method == 'GET') {
        return responseForGet(request);
      }

      if (request.method == 'POST' &&
          request.url.path == '/monthly-review/ai-reflection') {
        reflectionRequested = true;

        return http.Response(
          jsonEncode({
            'reflection':
                'You noticed a recurring pattern across the saved weeks.',
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
        home: Scaffold(body: MonthlyReviewScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(reflectionRequested, isFalse);

    final aiButton = find.byKey(const ValueKey('monthly-review-ai-button'));

    await scrollUntilBuilt(tester, aiButton);

    await tester.tap(aiButton);
    await tester.pumpAndSettle();

    expect(reflectionRequested, isTrue);

    expect(
      find.text('You noticed a recurring pattern across the saved weeks.'),
      findsOneWidget,
    );

    apiClient.close();
  });
}
