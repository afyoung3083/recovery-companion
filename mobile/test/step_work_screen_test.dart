import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/step_work_screen.dart';

Future<void> scrollUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));

    await tester.pumpAndSettle();
  }

  throw TestFailure('Expected Step Work widget did not become visible.');
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('Step Work renders current Step and assignments', (tester) async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/step-work');

      return http.Response(
        jsonEncode({
          'step_work': {
            'current_step': 8,
            'assignments': [
              {
                'id': 7,
                'step': 8,
                'text': 'Review inventory with sponsor.',
                'completed': false,
              },
              {
                'id': 8,
                'step': 8,
                'text': 'Write amends list.',
                'completed': true,
              },
              {
                'id': 9,
                'step': 7,
                'text': 'Different Step.',
                'completed': false,
              },
            ],
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
        theme: AppTheme.light(),
        home: Scaffold(body: StepWorkScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('step-work-current-step-card')),
      findsOneWidget,
    );

    expect(find.text('Step 8'), findsWidgets);

    await scrollUntilBuilt(tester, find.text('Review inventory with sponsor.'));

    expect(find.text('Review inventory with sponsor.'), findsOneWidget);

    expect(find.text('Write amends list.'), findsOneWidget);

    expect(find.text('Different Step.'), findsNothing);

    apiClient.close();
  });

  testWidgets('Step Work marks an open assignment complete', (tester) async {
    var completed = false;

    final mockClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/step-work') {
        return http.Response(
          jsonEncode({
            'step_work': {
              'current_step': 8,
              'assignments': [
                {
                  'id': 7,
                  'step': 8,
                  'text': 'Review inventory.',
                  'completed': completed,
                },
              ],
            },
          }),
          200,
        );
      }

      if (request.method == 'PUT' &&
          request.url.path == '/step-work/assignments/7/complete') {
        completed = true;

        return http.Response(
          jsonEncode({
            'assignment': {
              'id': 7,
              'step': 8,
              'text': 'Review inventory.',
              'completed': true,
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
        theme: AppTheme.light(),
        home: Scaffold(body: StepWorkScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    final completeButton = find.byKey(const ValueKey('step-work-complete-7'));

    await scrollUntilBuilt(tester, completeButton);

    await tester.tap(completeButton);

    await tester.pumpAndSettle();

    expect(completed, isTrue);

    apiClient.close();
  });
}
