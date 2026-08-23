import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/journal_screen.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets(
    'journal AI requires confirmation and shows selected reflection',
    (tester) async {
      var aiRequestCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/journal') {
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
            request.url.path ==
                '/journal/7/ai-reflection') {
          aiRequestCount += 1;

          expect(
            request.headers['Authorization'],
            'Bearer $token',
          );

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
          home: Scaffold(
            body: JournalScreen(
              apiClient: apiClient,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'AI reflection is optional. Only an entry you explicitly '
          'select for analysis is sent to the AI.',
        ),
        findsOneWidget,
      );

      final analyzeButton = find.byKey(
        const ValueKey('journal-ai-7'),
      );

      await tester.ensureVisible(analyzeButton);
      await tester.pumpAndSettle();

      await tester.tap(analyzeButton);
      await tester.pumpAndSettle();

      expect(aiRequestCount, 0);

      expect(
        find.text('Analyze this journal entry?'),
        findsOneWidget,
      );

      expect(
        find.text(
          'Only this selected journal entry will be sent to the AI '
          'for an optional recovery reflection. The reflection is '
          'not saved automatically.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Analyze Entry'),
      );

      await tester.pumpAndSettle();

      expect(aiRequestCount, 1);

      expect(
        find.byKey(
          const ValueKey(
            'journal-ai-reflection',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'You described choosing connection instead of isolation.',
        ),
        findsOneWidget,
      );

      apiClient.close();
    },
  );

  testWidgets(
    'cancelling journal AI sends nothing',
    (tester) async {
      var aiRequestCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/journal') {
          return http.Response(
            jsonEncode({
              'count': 1,
              'entries': [
                {
                  'id': 7,
                  'text': 'Private journal entry.',
                  'tags': [],
                },
              ],
            }),
            200,
          );
        }

        if (request.url.path.contains(
          'ai-reflection',
        )) {
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
          home: Scaffold(
            body: JournalScreen(
              apiClient: apiClient,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final analyzeButton = find.byKey(
        const ValueKey('journal-ai-7'),
      );

      await tester.ensureVisible(analyzeButton);
      await tester.pumpAndSettle();

      await tester.tap(analyzeButton);
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Cancel'),
      );

      await tester.pumpAndSettle();

      expect(aiRequestCount, 0);

      apiClient.close();
    },
  );
}
