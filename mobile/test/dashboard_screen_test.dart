import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/dashboard_screen.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets(
    'Dashboard shows deterministic recovery summary',
    (tester) async {
      final mockClient = MockClient((request) async {
        expect(
          request.method,
          'GET',
        );
        expect(
          request.url.path,
          '/dashboard',
        );
        expect(
          request.headers['Authorization'],
          'Bearer $token',
        );

        return http.Response(
          jsonEncode({
            'dashboard':
                'Daily Recovery Dashboard\n'
                'Sobriety: 12 day(s)\n'
                'Current Step: 4',
          }),
          200,
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
            body: DashboardScreen(
              apiClient: apiClient,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'dashboard-summary',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.textContaining(
          'Sobriety: 12 day(s)',
        ),
        findsOneWidget,
      );

      expect(
        find.textContaining(
          'Current Step: 4',
        ),
        findsOneWidget,
      );

      apiClient.close();
    },
  );

  testWidgets(
    'Dashboard retry reloads after API failure',
    (tester) async {
      var requestCount = 0;

      final mockClient = MockClient((request) async {
        requestCount += 1;

        if (requestCount == 1) {
          return http.Response(
            '{}',
            500,
          );
        }

        return http.Response(
          jsonEncode({
            'dashboard':
                'Daily Recovery Dashboard\n'
                'Sobriety: 12 day(s)',
          }),
          200,
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
            body: DashboardScreen(
              apiClient: apiClient,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'Unable to load Dashboard',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey(
            'dashboard-retry',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        requestCount,
        2,
      );

      expect(
        find.byKey(
          const ValueKey(
            'dashboard-summary',
          ),
        ),
        findsOneWidget,
      );

      apiClient.close();
    },
  );
}
