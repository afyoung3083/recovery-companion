import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/journal_screen.dart';

Future<void> scrollUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 15; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }

  throw TestFailure('Expected Journal widget did not become visible.');
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets(
    'journal AI requires confirmation and shows selected reflection',
    (tester) async {
      var aiRequestCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/journal') {
          return http.Response(
            jsonEncode({
              'count': 1,
              'entries': [
                {
                  'id': 7,
                  'created_at': '2026-08-22T20:00:00',
                  'text': 'I called my sponsor instead of isolating.',
                  'tags': ['connection'],
                },
              ],
            }),
            200,
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/journal/7/ai-reflection') {
          aiRequestCount += 1;

          expect(request.headers['Authorization'], 'Bearer $token');

          expect(request.body, isEmpty);

          return http.Response(
            jsonEncode({
              'entry_id': 7,
              'reflection':
                  'You described choosing connection instead of isolation.',
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
          home: Scaffold(body: JournalScreen(apiClient: apiClient)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Journal'), findsOneWidget);

      expect(
        find.byKey(const ValueKey('journal-entry-composer')),
        findsOneWidget,
      );

      final privacyText = find.text(
        'AI reflection is optional. Only an entry you explicitly '
        'select for analysis is sent to the AI.',
      );

      await scrollUntilVisible(tester, privacyText);

      expect(privacyText, findsOneWidget);

      final analyzeButton = find.byKey(const ValueKey('journal-ai-7'));

      await scrollUntilVisible(tester, analyzeButton);

      await tester.tap(analyzeButton);
      await tester.pumpAndSettle();

      expect(aiRequestCount, 0);

      expect(find.text('Analyze this journal entry?'), findsOneWidget);

      expect(
        find.text(
          'Only this selected journal entry will be sent to the AI '
          'for an optional recovery reflection. The reflection is '
          'not saved automatically.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Analyze Entry'));
      await tester.pumpAndSettle();

      expect(aiRequestCount, 1);

      final reflection = find.byKey(const ValueKey('journal-ai-reflection'));

      await scrollUntilVisible(tester, reflection);

      expect(reflection, findsOneWidget);

      expect(
        find.text('You described choosing connection instead of isolation.'),
        findsOneWidget,
      );

      apiClient.close();
    },
  );

  testWidgets('cancelling journal AI sends nothing', (tester) async {
    var aiRequestCount = 0;

    final mockClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/journal') {
        return http.Response(
          jsonEncode({
            'count': 1,
            'entries': [
              {'id': 7, 'text': 'Private journal entry.', 'tags': []},
            ],
          }),
          200,
        );
      }

      if (request.url.path.contains('ai-reflection')) {
        aiRequestCount += 1;
      }

      return http.Response('{}', 500);
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: JournalScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    final analyzeButton = find.byKey(const ValueKey('journal-ai-7'));

    await scrollUntilVisible(tester, analyzeButton);

    await tester.tap(analyzeButton);
    await tester.pumpAndSettle();

    expect(aiRequestCount, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(aiRequestCount, 0);

    apiClient.close();
  });
}
