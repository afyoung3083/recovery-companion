import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/step_work_screen.dart';

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
}) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));

    if (condition()) {
      return;
    }
  }

  throw TestFailure('Timed out waiting for $description.');
}

Future<void> revealStepWorkWidget(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump();

    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }

    final listViews = find.byType(ListView);

    if (listViews.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      continue;
    }

    await tester.drag(listViews.first, const Offset(0, -320));

    await tester.pumpAndSettle();
  }

  throw TestFailure(
    'Expected Step Work widget did not '
    'become visible: $finder',
  );
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

    addTearDown(apiClient.close);

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

    final firstAssignment = find.text('Review inventory with sponsor.');

    await revealStepWorkWidget(tester, firstAssignment);

    expect(firstAssignment, findsOneWidget);

    expect(find.text('Write amends list.'), findsOneWidget);

    expect(find.text('Different Step.'), findsNothing);
  });

  testWidgets('Step Work completion can be checked and reopened', (
    tester,
  ) async {
    var completed = false;

    final submittedStates = <bool>[];

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
          request.url.path ==
              '/step-work/'
                  'assignments/7/completed') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        completed = body['completed'] as bool;

        submittedStates.add(completed);

        return http.Response(
          jsonEncode({
            'assignment': {
              'id': 7,
              'step': 8,
              'text': 'Review inventory.',
              'completed': completed,
              'completed_at': completed ? '2026-09-01T00:00:00' : null,
            },
          }),
          200,
        );
      }

      throw StateError(
        'Unexpected request: '
        '${request.method} '
        '${request.url}',
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: StepWorkScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    Finder checkbox() => find.byKey(const ValueKey('step-work-completed-7'));

    await revealStepWorkWidget(tester, checkbox());

    expect(tester.widget<Checkbox>(checkbox()).value, isFalse);

    await tester.tap(checkbox());

    await pumpUntil(
      tester,
      () => submittedStates.length == 1,
      description: 'completed=true request',
    );

    await tester.pumpAndSettle();

    expect(submittedStates, [true]);

    /*
       * The FutureBuilder reloads after the
       * update and the ListView returns to its
       * initial position. Reacquire and reveal
       * the rebuilt checkbox before using it.
       */
    await revealStepWorkWidget(tester, checkbox());

    expect(tester.widget<Checkbox>(checkbox()).value, isTrue);

    await tester.tap(checkbox());

    await pumpUntil(
      tester,
      () => submittedStates.length == 2,
      description: 'completed=false request',
    );

    await tester.pumpAndSettle();

    expect(submittedStates, [true, false]);

    expect(completed, isFalse);
  });

  testWidgets('Step Work assignment can be edited', (tester) async {
    var assignmentText = 'Mispelled assignment';

    var updateRequestCount = 0;

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
                  'text': assignmentText,
                  'completed': false,
                },
              ],
            },
          }),
          200,
        );
      }

      if (request.method == 'PUT' &&
          request.url.path ==
              '/step-work/'
                  'assignments/7') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        assignmentText = body['text'].toString();

        updateRequestCount++;

        return http.Response(
          jsonEncode({
            'assignment': {
              'id': 7,
              'step': 8,
              'text': assignmentText,
              'completed': false,
            },
          }),
          200,
        );
      }

      throw StateError(
        'Unexpected request: '
        '${request.method} '
        '${request.url}',
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: StepWorkScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    final editButton = find.byKey(const ValueKey('step-work-edit-7'));

    await revealStepWorkWidget(tester, editButton);

    await tester.tap(editButton);

    await tester.pumpAndSettle();

    final editField = find.byKey(const ValueKey('step-work-edit-input'));

    expect(editField, findsOneWidget);

    await tester.enterText(editField, 'Corrected assignment');

    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('step-work-save-edit')));

    await pumpUntil(
      tester,
      () => updateRequestCount == 1,
      description: 'assignment edit request',
    );

    await tester.pumpAndSettle();

    expect(assignmentText, 'Corrected assignment');

    final correctedText = find.text('Corrected assignment');

    /*
       * Saving reloads Step Work and resets
       * the scroll position, so reveal the
       * rebuilt assignment before asserting.
       */
    await revealStepWorkWidget(tester, correctedText);

    expect(correctedText, findsOneWidget);

    expect(find.text('Mispelled assignment'), findsNothing);
  });
}
