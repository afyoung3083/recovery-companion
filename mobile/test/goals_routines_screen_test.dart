import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/goals_screen.dart';
import 'package:mobile/routines_screen.dart';

Future<void> scrollUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));

    await tester.pumpAndSettle();
  }

  throw TestFailure('Expected widget did not become visible.');
}

void main() {
  testWidgets('Goals uses recovery design system and empty state', (
    tester,
  ) async {
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode({'goals': []}), 200);
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: GoalsScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('goals-add-card')), findsOneWidget);

    expect(find.text('Add a goal'), findsOneWidget);

    await scrollUntilBuilt(tester, find.text('No active goals'));

    expect(find.text('No active goals'), findsOneWidget);

    apiClient.close();
  });

  testWidgets('Routines uses recovery design system and empty state', (
    tester,
  ) async {
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode({'routines': []}), 200);
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: RoutinesScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('routines-add-card')), findsOneWidget);

    expect(find.text('Add a routine'), findsOneWidget);

    await scrollUntilBuilt(tester, find.text('No active routines'));

    expect(find.text('No active routines'), findsOneWidget);

    apiClient.close();
  });
}
