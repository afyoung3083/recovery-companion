import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/profile_screen.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets(
    'Profile displays saved sobriety date',
    (tester) async {
      final mockClient = MockClient((request) async {
        expect(
          request.method,
          'GET',
        );
        expect(
          request.url.path,
          '/profile',
        );
        expect(
          request.headers['Authorization'],
          'Bearer $token',
        );

        return http.Response(
          jsonEncode({
            'profile': {
              'sobriety_date': '2026-08-12',
            },
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
            body: ProfileScreen(
              apiClient: apiClient,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'profile-sobriety-date',
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          '2026-08-12',
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'Change Sobriety Date',
        ),
        findsOneWidget,
      );

      apiClient.close();
    },
  );

  testWidgets(
    'Profile date picker saves selected sobriety date',
    (tester) async {
      var updateCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/profile') {
          return http.Response(
            jsonEncode({
              'profile': {
                'sobriety_date': '2026-08-12',
              },
            }),
            200,
          );
        }

        if (request.method == 'PUT' &&
            request.url.path ==
                '/profile/sobriety-date') {
          updateCount += 1;

          expect(
            request.headers['Authorization'],
            'Bearer $token',
          );

          expect(
            jsonDecode(request.body),
            {
              'sobriety_date': '2026-08-12',
            },
          );

          return http.Response(
            jsonEncode({
              'profile': {
                'sobriety_date': '2026-08-12',
              },
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
            body: ProfileScreen(
              apiClient: apiClient,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey(
            'profile-change-sobriety-date',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(
          DatePickerDialog,
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.text('OK'),
      );
      await tester.pumpAndSettle();

      expect(
        updateCount,
        1,
      );

      expect(
        find.text(
          '2026-08-12',
        ),
        findsOneWidget,
      );

      apiClient.close();
    },
  );
}
