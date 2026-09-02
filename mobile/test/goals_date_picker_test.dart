import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/goals_screen.dart';

void main() {
  testWidgets('Goal target date uses a calendar and can be cleared', (
    tester,
  ) async {
    final mockClient = MockClient((request) async {
      if (request.method != 'GET' || request.url.path != '/goals') {
        throw StateError(
          'Unexpected request: '
          '${request.method} '
          '${request.url}',
        );
      }

      return http.Response(jsonEncode({'goals': []}), 200);
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: mockClient,
    );

    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalsScreen(
            apiClient: apiClient,
            now: () => DateTime(2026, 9, 1),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('goals-target-date-field'));

    expect(field, findsOneWidget);

    expect(tester.widget<TextField>(field).readOnly, isTrue);

    await tester.tap(field);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    final dayFifteen = find.text('15');

    expect(dayFifteen, findsWidgets);

    await tester.tap(dayFifteen.last);

    await tester.tap(find.text('OK'));

    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller?.text, '2026-09-15');

    final clearButton = find.byKey(const ValueKey('goals-clear-target-date'));

    expect(clearButton, findsOneWidget);

    await tester.tap(clearButton);
    await tester.pump();

    expect(tester.widget<TextField>(field).controller?.text, isEmpty);
  });
}
