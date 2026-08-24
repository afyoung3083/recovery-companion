import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/daily_checkin_screen.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('recent check-in AI requires confirmation and shows reflection', (
    tester,
  ) async {
    var aiRequestCount = 0;

    final mockClient = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/daily-checkin/today') {
        return http.Response(
          jsonEncode({
            'date': '2026-08-23',
            'checkin': {
              'date': '2026-08-23',
              'prayer_meditation': true,
              'recovery_contact': true,
              'meeting': false,
              'step_work': true,
              'journal': true,
              'service': false,
              'note': 'Stayed connected today.',
            },
          }),
          200,
        );
      }

      if (request.method == 'POST' &&
          request.url.path == '/daily-checkin/ai-reflection') {
        aiRequestCount += 1;

        expect(request.headers['Authorization'], 'Bearer $token');

        expect(request.body, isEmpty);

        return http.Response(
          jsonEncode({
            'checkin_count': 3,
            'reflection': 'Recovery contact has been visible recently.',
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
        home: Scaffold(body: DailyCheckInScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    final analyzeButton = find.byKey(const ValueKey('daily-checkin-ai'));

    expect(analyzeButton, findsOneWidget);

    expect(
      find.text(
        'Only a locally built summary of up to seven recent saved '
        'check-ins is sent, and only after you confirm. The AI '
        'reflection is not saved automatically.',
      ),
      findsOneWidget,
    );

    await tester.tap(analyzeButton);
    await tester.pumpAndSettle();

    expect(aiRequestCount, 0);

    expect(find.text('Analyze recent check-ins?'), findsOneWidget);

    expect(
      find.text(
        'Recovery Companion will create a summary of your most '
        'recent saved check-ins, up to seven, and send only that '
        'summary to the AI for an optional recovery reflection. '
        'The reflection is not saved automatically.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Analyze Check-Ins'));

    await tester.pumpAndSettle();

    expect(aiRequestCount, 1);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('daily-checkin-ai-reflection')),
      findsOneWidget,
    );

    expect(
      find.text('Recovery contact has been visible recently.'),
      findsOneWidget,
    );

    expect(find.text('Based on 3 recent check-ins.'), findsOneWidget);

    apiClient.close();
  });

  testWidgets('cancelling recent check-in AI sends nothing', (tester) async {
    var aiRequestCount = 0;

    final mockClient = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/daily-checkin/today') {
        return http.Response(
          jsonEncode({'date': '2026-08-23', 'checkin': null}),
          200,
        );
      }

      if (request.method == 'POST' &&
          request.url.path == '/daily-checkin/ai-reflection') {
        aiRequestCount += 1;

        return http.Response(
          jsonEncode({
            'checkin_count': 1,
            'reflection': 'Should not be requested.',
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
        home: Scaffold(body: DailyCheckInScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-checkin-ai')));

    await tester.pumpAndSettle();

    expect(aiRequestCount, 0);

    await tester.tap(find.text('Cancel'));

    await tester.pumpAndSettle();

    expect(aiRequestCount, 0);

    apiClient.close();
  });
}
