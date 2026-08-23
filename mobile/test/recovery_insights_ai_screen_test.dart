import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/insights_screen.dart';

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
          return http.Response(
            jsonEncode({
              'recovery_insights':
                  'Recovery Insights\n'
                  'Current Step: 4\n'
                  'Active Recovery Goals: 2',
            }),
            200,
          );
        }

        if (request.method == 'POST' &&
            request.url.path ==
                '/recovery-insights/ai-reflection') {
          aiRequestCount += 1;

          expect(
            request.headers['Authorization'],
            'Bearer $token',
          );

          expect(
            request.body,
            isEmpty,
          );

          return http.Response(
            jsonEncode({
              'reflection':
                  'Human connection may be worth continuing '
                  'to prioritize.',
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
            body: InsightsScreen(
              apiClient: apiClient,
            ),
          ),
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

      await tester.drag(
        find.byType(ListView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      final analyzeButton = find.byKey(
        const ValueKey(
          'recovery-insights-ai',
        ),
      );

      expect(
        analyzeButton,
        findsOneWidget,
      );

      await tester.tap(
        analyzeButton,
      );
      await tester.pumpAndSettle();

      expect(
        aiRequestCount,
        0,
      );

      expect(
        find.text(
          'Analyze Recovery Insights?',
        ),
        findsOneWidget,
      );

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

      await tester.tap(
        find.text(
          'Analyze Insights',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        aiRequestCount,
        1,
      );

      await tester.drag(
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'recovery-insights-ai-reflection',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'Human connection may be worth continuing to prioritize.',
        ),
        findsOneWidget,
      );

      apiClient.close();
    },
  );

  testWidgets(
    'cancelling Recovery Insights AI sends nothing',
    (tester) async {
      var aiRequestCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/recovery-insights') {
          return http.Response(
            jsonEncode({
              'recovery_insights':
                  'Recovery Insights\nCurrent Step: 4',
            }),
            200,
          );
        }

        if (request.method == 'POST' &&
            request.url.path ==
                '/recovery-insights/ai-reflection') {
          aiRequestCount += 1;

          return http.Response(
            jsonEncode({
              'reflection':
                  'This should not be requested.',
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
            body: InsightsScreen(
              apiClient: apiClient,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(ListView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey(
            'recovery-insights-ai',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        aiRequestCount,
        0,
      );

      await tester.tap(
        find.text(
          'Cancel',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        aiRequestCount,
        0,
      );

      apiClient.close();
    },
  );
}
