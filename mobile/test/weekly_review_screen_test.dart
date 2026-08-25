import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/weekly_review_screen.dart';

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

  throw TestFailure('Expected Weekly Review widget did not become visible.');
}

http.Response responseForGet(http.Request request) {
  switch (request.url.path) {
    case '/weekly-review/current':
      return http.Response(
        jsonEncode({'review': 'Weekly Recovery Review\nCheck-In Days: 5/7'}),
        200,
      );

    case '/weekly-review/history':
      return http.Response(
        jsonEncode({
          'history': [
            {
              'week_start': '2026-08-11',
              'week_end': '2026-08-17',
              'checkin_days': 4,
              'journal_entries': 2,
            },
            {
              'week_start': '2026-08-18',
              'week_end': '2026-08-24',
              'checkin_days': 5,
              'journal_entries': 3,
            },
          ],
        }),
        200,
      );

    case '/weekly-review/comparison':
      return http.Response(
        jsonEncode({'comparison': 'Check-In Days: 4 -> 5'}),
        200,
      );
  }

  throw StateError('Unexpected GET: ${request.url}');
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('Weekly Review renders review history and comparison', (
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
        home: Scaffold(body: WeeklyReviewScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('weekly-review-screen')), findsOneWidget);

    expect(find.textContaining('Weekly Recovery Review'), findsOneWidget);

    await scrollUntilBuilt(tester, find.text('2026-08-18 to 2026-08-24'));

    expect(find.text('2026-08-18 to 2026-08-24'), findsOneWidget);

    await scrollUntilBuilt(
      tester,
      find.textContaining('Check-In Days: 4 -> 5'),
    );

    expect(find.textContaining('Check-In Days: 4 -> 5'), findsOneWidget);

    apiClient.close();
  });

  testWidgets('Weekly Review saves a snapshot', (tester) async {
    var snapshotSaved = false;

    final mockClient = MockClient((request) async {
      if (request.method == 'GET') {
        return responseForGet(request);
      }

      if (request.method == 'POST' &&
          request.url.path == '/weekly-review/snapshot') {
        snapshotSaved = true;

        return http.Response(
          jsonEncode({
            'snapshot': {'week_end': '2026-08-24'},
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
        home: Scaffold(body: WeeklyReviewScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('weekly-review-save')));

    await tester.pumpAndSettle();

    expect(snapshotSaved, isTrue);

    expect(find.text('Weekly review saved.'), findsOneWidget);

    apiClient.close();
  });

  testWidgets('Weekly Review AI reflection runs only when requested', (
    tester,
  ) async {
    var reflectionRequested = false;

    final mockClient = MockClient((request) async {
      if (request.method == 'GET') {
        return responseForGet(request);
      }

      if (request.method == 'POST' &&
          request.url.path == '/weekly-review/ai-reflection') {
        reflectionRequested = true;

        return http.Response(
          jsonEncode({
            'reflection': 'You noticed greater consistency this week.',
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
        home: Scaffold(body: WeeklyReviewScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(reflectionRequested, isFalse);

    final aiButton = find.byKey(const ValueKey('weekly-review-ai-button'));

    await scrollUntilBuilt(tester, aiButton);

    await tester.tap(aiButton);
    await tester.pumpAndSettle();

    expect(reflectionRequested, isTrue);

    expect(
      find.text('You noticed greater consistency this week.'),
      findsOneWidget,
    );

    apiClient.close();
  });
}
