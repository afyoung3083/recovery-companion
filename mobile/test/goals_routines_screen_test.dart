import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/goals_screen.dart';
import 'package:mobile/local_goals_repository.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/routines_screen.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class FakeLocalGoalsRepository extends LocalGoalsRepository {
  FakeLocalGoalsRepository({
    List<Map<String, dynamic>> activeGoals = const [],
    List<Map<String, dynamic>> completedGoals = const [],
  }) : _activeGoals = activeGoals
           .map((goal) => Map<String, dynamic>.from(goal))
           .toList(),
       _completedGoals = completedGoals
           .map((goal) => Map<String, dynamic>.from(goal))
           .toList(),
       super(
         store: LocalRecoveryStore(
           dataFile: File('unused-goals-widget-test.enc'),
           keyStore: MemorySecureKeyValueStore(),
         ),
       );

  final List<Map<String, dynamic>> _activeGoals;
  final List<Map<String, dynamic>> _completedGoals;

  @override
  Future<Map<String, dynamic>> getGoals() async {
    return {'goals': _copyGoals(_activeGoals)};
  }

  @override
  Future<Map<String, dynamic>> getCompletedGoals() async {
    return {'goals': _copyGoals(_completedGoals)};
  }

  @override
  Future<Map<String, dynamic>> createGoal({
    required String text,
    required String area,
    String targetDate = '',
  }) async {
    final goal = <String, dynamic>{
      'id': _nextId(),
      'text': text,
      'area': area,
      'target_date': targetDate,
      'active': true,
      'completed': false,
    };
    _activeGoals.add(goal);
    return {'goal': Map<String, dynamic>.from(goal)};
  }

  @override
  Future<Map<String, dynamic>> completeGoal(int goalId) async {
    final index = _activeGoals.indexWhere((goal) => goal['id'] == goalId);
    if (index < 0) {
      throw StateError('Goal $goalId was not found.');
    }

    final goal = {
      ..._activeGoals.removeAt(index),
      'active': false,
      'completed': true,
      'completed_at': '2026-09-04T18:00:00Z',
    };
    _completedGoals.add(goal);
    return {'goal': Map<String, dynamic>.from(goal)};
  }

  int _nextId() {
    final ids = [
      ..._activeGoals,
      ..._completedGoals,
    ].map((goal) => goal['id']).whereType<int>();
    return (ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b)) + 1;
  }

  List<Map<String, dynamic>> _copyGoals(List<Map<String, dynamic>> goals) {
    return goals.map(Map<String, dynamic>.from).toList();
  }
}

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<Map<String, String>> readAll() async => {};

  @override
  Future<void> write({required String key, required String value}) async {}
}

Future<void> scrollUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  throw TestFailure('Expected widget did not become visible.');
}

Future<void> pumpGoalsAsyncWork(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
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

    await pumpGoalsAsyncWork(tester);

    expect(find.byKey(const ValueKey('goals-add-card')), findsOneWidget);

    expect(find.text('Add a goal'), findsOneWidget);

    await scrollUntilBuilt(tester, find.text('No active goals'));

    expect(find.text('No active goals'), findsOneWidget);

    apiClient.close();
  });

  testWidgets('local active and completed goals render in separate areas', (
    tester,
  ) async {
    final repository = FakeLocalGoalsRepository(
      activeGoals: [
        {
          'id': 1,
          'text': 'Call sponsor',
          'area': 'connection',
          'target_date': '2026-09-20',
          'active': true,
          'completed': false,
        },
      ],
      completedGoals: [
        {
          'id': 2,
          'text': 'Attend meeting',
          'area': 'meetings',
          'target_date': '',
          'active': false,
          'completed': true,
          'completed_at': '2026-09-04T18:00:00Z',
        },
      ],
    );
    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: GoalsScreen(apiClient: apiClient, localRepository: repository),
        ),
      ),
    );
    await pumpGoalsAsyncWork(tester);

    expect(find.text('Active Goals'), findsOneWidget);
    expect(find.text('Call sponsor'), findsOneWidget);

    await scrollUntilBuilt(tester, find.text('Completed Goals'));

    expect(find.text('Completed Goals'), findsOneWidget);

    await scrollUntilBuilt(tester, find.text('Attend meeting'));

    expect(find.text('Attend meeting'), findsOneWidget);
    expect(find.text('Completed 2026-09-04T18:00:00Z'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets('no completed goals shows a clean empty state', (tester) async {
    final repository = FakeLocalGoalsRepository(
      activeGoals: [
        {
          'id': 1,
          'text': 'Call sponsor',
          'area': 'connection',
          'target_date': '',
          'active': true,
          'completed': false,
        },
      ],
    );
    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: GoalsScreen(apiClient: apiClient, localRepository: repository),
        ),
      ),
    );
    await pumpGoalsAsyncWork(tester);

    await scrollUntilBuilt(tester, find.text('No completed goals yet.'));

    expect(find.text('No completed goals yet.'), findsOneWidget);
  });

  testWidgets('completing a local goal moves it to completed history', (
    tester,
  ) async {
    final repository = FakeLocalGoalsRepository(
      activeGoals: [
        {
          'id': 1,
          'text': 'Attend meeting',
          'area': 'meetings',
          'target_date': '',
          'active': true,
          'completed': false,
        },
      ],
    );

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: GoalsScreen(apiClient: apiClient, localRepository: repository),
        ),
      ),
    );
    await pumpGoalsAsyncWork(tester);

    final completeButton = find.widgetWithText(FilledButton, 'Complete');
    await scrollUntilBuilt(tester, completeButton);
    await tester.ensureVisible(completeButton);
    await tester.tap(completeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    await scrollUntilBuilt(tester, find.text('No active goals'));
    expect(find.text('No active goals'), findsOneWidget);
    expect(find.text('Attend meeting'), findsOneWidget);
    expect(find.text('Completed 2026-09-04T18:00:00Z'), findsOneWidget);
  });

  testWidgets('local Add Goal workflow remains available', (tester) async {
    final repository = FakeLocalGoalsRepository();
    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: GoalsScreen(apiClient: apiClient, localRepository: repository),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextField).first, 'Call sponsor');
    await tester.tap(find.text('Add Goal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Goal added.'), findsOneWidget);
    expect((await repository.getGoals())['goals'], hasLength(1));
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
