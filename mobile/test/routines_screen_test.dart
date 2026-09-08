import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/local_routines_repository.dart';
import 'package:mobile/routines_screen.dart';
import 'package:mobile/secure_offline_cache_store.dart';

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

class FakeLocalRoutinesRepository extends LocalRoutinesRepository {
  FakeLocalRoutinesRepository({
    List<Map<String, dynamic>> activeRoutines = const [],
    List<Map<String, dynamic>> inactiveRoutines = const [],
    this.failUpdates = false,
  }) : _activeRoutines = activeRoutines
           .map((routine) => Map<String, dynamic>.from(routine))
           .toList(),
       _inactiveRoutines = inactiveRoutines
           .map((routine) => Map<String, dynamic>.from(routine))
           .toList(),
       super(
         store: LocalRecoveryStore(
           dataFile: File('unused-routines-widget-test.enc'),
           keyStore: MemorySecureKeyValueStore(),
         ),
       );

  final List<Map<String, dynamic>> _activeRoutines;
  final List<Map<String, dynamic>> _inactiveRoutines;
  final bool failUpdates;

  @override
  Future<Map<String, dynamic>> getRoutines() async {
    return {'routines': _copy(_activeRoutines)};
  }

  @override
  Future<List<Map<String, dynamic>>> getInactiveRoutines() async {
    return _copy(_inactiveRoutines);
  }

  @override
  Future<Map<String, dynamic>> createRoutine({
    required String text,
    required String area,
    required String frequency,
    String dayOfWeek = '',
  }) async {
    final routine = <String, dynamic>{
      'id': _nextId(),
      'text': text,
      'area': area,
      'frequency': frequency,
      'day_of_week': frequency == 'weekly' ? dayOfWeek : '',
      'active': true,
    };
    _activeRoutines.add(routine);
    return {'routine': Map<String, dynamic>.from(routine)};
  }

  @override
  Future<Map<String, dynamic>> updateRoutine({
    required int routineId,
    required String text,
    required String area,
    required String frequency,
    required String dayOfWeek,
  }) async {
    if (failUpdates) {
      throw StateError('Update failed');
    }

    final all = [..._activeRoutines, ..._inactiveRoutines];
    final index = all.indexWhere((routine) => routine['id'] == routineId);
    if (index < 0) {
      throw StateError('Routine $routineId was not found.');
    }

    final updated = {
      ...all[index],
      'text': text,
      'area': area,
      'frequency': frequency,
      'day_of_week': frequency == 'weekly' ? dayOfWeek : '',
    };

    final activeIndex = _activeRoutines.indexWhere(
      (routine) => routine['id'] == routineId,
    );
    if (activeIndex >= 0) {
      _activeRoutines[activeIndex] = updated;
    } else {
      final inactiveIndex = _inactiveRoutines.indexWhere(
        (routine) => routine['id'] == routineId,
      );
      _inactiveRoutines[inactiveIndex] = updated;
    }

    return {'routine': Map<String, dynamic>.from(updated)};
  }

  @override
  Future<Map<String, dynamic>> setRoutineActive({
    required int routineId,
    required bool active,
  }) async {
    if (active) {
      final index = _inactiveRoutines.indexWhere(
        (routine) => routine['id'] == routineId,
      );
      if (index < 0) {
        throw StateError('Routine $routineId was not found.');
      }
      final routine = {..._inactiveRoutines.removeAt(index), 'active': true};
      _activeRoutines.add(routine);
      return {'routine': Map<String, dynamic>.from(routine)};
    }

    final index = _activeRoutines.indexWhere(
      (routine) => routine['id'] == routineId,
    );
    if (index < 0) {
      throw StateError('Routine $routineId was not found.');
    }
    final routine = {..._activeRoutines.removeAt(index), 'active': false};
    _inactiveRoutines.add(routine);
    return {'routine': Map<String, dynamic>.from(routine)};
  }

  int _nextId() {
    final ids = [
      ..._activeRoutines,
      ..._inactiveRoutines,
    ].map((routine) => routine['id']).whereType<int>();
    return (ids.isEmpty ? 0 : ids.reduce((a, b) => a > b ? a : b)) + 1;
  }

  List<Map<String, dynamic>> _copy(List<Map<String, dynamic>> routines) {
    return routines.map(Map<String, dynamic>.from).toList();
  }
}

Future<void> pumpRoutinesAsyncWork(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
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

  throw TestFailure('Expected Routine widget did not become visible.');
}

ApiClient testApiClient({http.Client? client}) {
  return ApiClient(
    baseUrl: 'http://example.test',
    apiToken: 'test-token',
    httpClient: client ?? MockClient((_) async => http.Response('{}', 500)),
  );
}

void main() {
  testWidgets('default Routine view is List and can switch to Card', (
    tester,
  ) async {
    final repository = FakeLocalRoutinesRepository(
      activeRoutines: [
        {
          'id': 1,
          'text': 'Morning prayer',
          'area': 'prayer',
          'frequency': 'weekly',
          'day_of_week': 'monday',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoutinesScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      ),
    );
    await pumpRoutinesAsyncWork(tester);

    await scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('routine-tile-1')),
    );
    expect(find.byKey(const ValueKey('routine-tile-1')), findsOneWidget);

    final cardChip = find.byKey(const ValueKey('routines-view-card'));
    await scrollUntilBuilt(tester, cardChip);
    await tester.tap(cardChip);
    await pumpRoutinesAsyncWork(tester);

    expect(find.byKey(const ValueKey('routine-tile-1')), findsNothing);
    expect(find.text('Morning prayer'), findsOneWidget);

    expect((await repository.getRoutines())['routines'], hasLength(1));
  });

  testWidgets(
    'active and inactive routines render in their own sections without duplication',
    (tester) async {
      final repository = FakeLocalRoutinesRepository(
        activeRoutines: [
          {
            'id': 1,
            'text': 'Active routine',
            'area': 'connection',
            'frequency': 'daily',
            'day_of_week': '',
            'active': true,
          },
        ],
        inactiveRoutines: [
          {
            'id': 2,
            'text': 'Paused routine',
            'area': 'service',
            'frequency': 'weekly',
            'day_of_week': 'friday',
            'active': false,
          },
        ],
      );
      final apiClient = testApiClient();
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RoutinesScreen(
              apiClient: apiClient,
              localRepository: repository,
            ),
          ),
        ),
      );
      await pumpRoutinesAsyncWork(tester);

      await scrollUntilBuilt(tester, find.text('Active routine'));
      expect(find.text('Active routine'), findsOneWidget);

      await scrollUntilBuilt(tester, find.text('Inactive Routines'));
      await scrollUntilBuilt(tester, find.text('Paused routine'));
      expect(find.text('Paused routine'), findsOneWidget);
    },
  );

  testWidgets(
    'deactivating an active routine moves it to Inactive without duplication',
    (tester) async {
      final repository = FakeLocalRoutinesRepository(
        activeRoutines: [
          {
            'id': 5,
            'text': 'Evening reading',
            'area': 'journal',
            'frequency': 'daily',
            'day_of_week': '',
            'active': true,
          },
        ],
      );
      final apiClient = testApiClient();
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RoutinesScreen(
              apiClient: apiClient,
              localRepository: repository,
            ),
          ),
        ),
      );
      await pumpRoutinesAsyncWork(tester);

      final tile = find.byKey(const ValueKey('routine-tile-5'));
      await scrollUntilBuilt(tester, tile);
      final toggle = find.descendant(of: tile, matching: find.byType(Switch));
      await tester.tap(toggle);
      await pumpRoutinesAsyncWork(tester);

      await scrollUntilBuilt(tester, find.text('Evening reading'));
      expect(find.text('Evening reading'), findsOneWidget);
      expect(repository._activeRoutines, isEmpty);
      expect(repository._inactiveRoutines, hasLength(1));
    },
  );

  testWidgets(
    'activating an inactive routine moves it back to Active without duplication',
    (tester) async {
      final repository = FakeLocalRoutinesRepository(
        inactiveRoutines: [
          {
            'id': 6,
            'text': 'Weekend call',
            'area': 'connection',
            'frequency': 'weekly',
            'day_of_week': 'saturday',
            'active': false,
          },
        ],
      );
      final apiClient = testApiClient();
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RoutinesScreen(
              apiClient: apiClient,
              localRepository: repository,
            ),
          ),
        ),
      );
      await pumpRoutinesAsyncWork(tester);

      final tile = find.byKey(const ValueKey('routine-tile-6'));
      await scrollUntilBuilt(tester, tile);
      final toggle = find.descendant(of: tile, matching: find.byType(Switch));
      await tester.tap(toggle);
      await pumpRoutinesAsyncWork(tester);

      await scrollUntilBuilt(tester, find.text('Weekend call'));
      expect(find.text('Weekend call'), findsOneWidget);
      expect(repository._inactiveRoutines, isEmpty);
      expect(repository._activeRoutines, hasLength(1));
    },
  );

  testWidgets('active routine Edit loads fields and saves changes', (
    tester,
  ) async {
    final repository = FakeLocalRoutinesRepository(
      activeRoutines: [
        {
          'id': 7,
          'text': 'Original routine',
          'area': 'health',
          'frequency': 'weekly',
          'day_of_week': 'tuesday',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoutinesScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      ),
    );
    await pumpRoutinesAsyncWork(tester);

    final editButton = find.byKey(const ValueKey('routine-edit-7'));
    await scrollUntilBuilt(tester, editButton);
    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Edit Routine'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('routine-edit-text')))
          .controller
          ?.text,
      'Original routine',
    );
    expect(find.byKey(const ValueKey('routine-edit-day')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('routine-edit-text')),
      'Updated routine',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('routine-edit-save')));
    await pumpRoutinesAsyncWork(tester);

    expect(find.text('Routine updated.'), findsOneWidget);
    expect(find.text('Updated routine'), findsOneWidget);
    expect(repository._activeRoutines.single['active'], isTrue);
  });

  testWidgets('inactive routine can be edited and remains inactive', (
    tester,
  ) async {
    final repository = FakeLocalRoutinesRepository(
      inactiveRoutines: [
        {
          'id': 8,
          'text': 'Paused practice',
          'area': 'other',
          'frequency': 'daily',
          'day_of_week': '',
          'active': false,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoutinesScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      ),
    );
    await pumpRoutinesAsyncWork(tester);

    final editButton = find.byKey(const ValueKey('routine-edit-8'));
    await scrollUntilBuilt(tester, editButton);
    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('routine-edit-text')),
      'Corrected paused practice',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('routine-edit-save')));
    await pumpRoutinesAsyncWork(tester);

    expect(find.text('Corrected paused practice'), findsOneWidget);
    expect(repository._inactiveRoutines.single['active'], isFalse);
    expect(repository._activeRoutines, isEmpty);
  });

  testWidgets('Daily edit hides day of week and clears it on save', (
    tester,
  ) async {
    final repository = FakeLocalRoutinesRepository(
      activeRoutines: [
        {
          'id': 9,
          'text': 'Weekly routine',
          'area': 'other',
          'frequency': 'weekly',
          'day_of_week': 'monday',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoutinesScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      ),
    );
    await pumpRoutinesAsyncWork(tester);

    final editButton = find.byKey(const ValueKey('routine-edit-9'));
    await scrollUntilBuilt(tester, editButton);
    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('routine-edit-day')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('routine-edit-frequency')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Daily').last);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('routine-edit-day')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('routine-edit-save')));
    await pumpRoutinesAsyncWork(tester);

    expect(repository._activeRoutines.single['frequency'], 'daily');
    expect(repository._activeRoutines.single['day_of_week'], isEmpty);
  });

  testWidgets('cancel leaves the routine unchanged', (tester) async {
    final repository = FakeLocalRoutinesRepository(
      activeRoutines: [
        {
          'id': 10,
          'text': 'Keep this routine',
          'area': 'other',
          'frequency': 'daily',
          'day_of_week': '',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoutinesScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      ),
    );
    await pumpRoutinesAsyncWork(tester);

    final editButton = find.byKey(const ValueKey('routine-edit-10'));
    await scrollUntilBuilt(tester, editButton);
    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('routine-edit-text')),
      'Unsaved change',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Edit Routine'), findsNothing);
    expect(find.text('Keep this routine'), findsOneWidget);
    expect(repository._activeRoutines.single['text'], 'Keep this routine');
  });

  testWidgets('edit failure keeps the editor open with typed values', (
    tester,
  ) async {
    final repository = FakeLocalRoutinesRepository(
      activeRoutines: [
        {
          'id': 11,
          'text': 'Original routine',
          'area': 'other',
          'frequency': 'daily',
          'day_of_week': '',
          'active': true,
        },
      ],
      failUpdates: true,
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoutinesScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      ),
    );
    await pumpRoutinesAsyncWork(tester);

    final editButton = find.byKey(const ValueKey('routine-edit-11'));
    await scrollUntilBuilt(tester, editButton);
    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('routine-edit-text')),
      'Retry this edit',
    );
    await tester.tap(find.byKey(const ValueKey('routine-edit-save')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Edit Routine'), findsOneWidget);
    expect(
      find.text('Unable to update this routine. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('routine-edit-text')))
          .controller
          ?.text,
      'Retry this edit',
    );
  });

  testWidgets('local Add Routine workflow remains available', (tester) async {
    final repository = FakeLocalRoutinesRepository();
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RoutinesScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      ),
    );
    await pumpRoutinesAsyncWork(tester);

    await tester.enterText(find.byType(TextField).first, 'Call sponsor');
    await tester.tap(find.text('Add Routine'));
    await pumpRoutinesAsyncWork(tester);

    expect(find.text('Routine added.'), findsOneWidget);
    expect((await repository.getRoutines())['routines'], hasLength(1));
  });

  testWidgets(
    'non-local Routines screen constructs safely without local controls',
    (tester) async {
      final apiClient = testApiClient(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'routines': []}), 200);
        }),
      );
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: RoutinesScreen(apiClient: apiClient)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('routines-add-card')), findsOneWidget);
      expect(find.text('Inactive Routines'), findsNothing);
    },
  );

  testWidgets(
    'routine display never contains the old question mark separator',
    (tester) async {
      final repository = FakeLocalRoutinesRepository(
        activeRoutines: [
          {
            'id': 12,
            'text': 'Weekly meeting',
            'area': 'meetings',
            'frequency': 'weekly',
            'day_of_week': 'wednesday',
            'active': true,
          },
        ],
      );
      final apiClient = testApiClient();
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RoutinesScreen(
              apiClient: apiClient,
              localRepository: repository,
            ),
          ),
        ),
      );
      await pumpRoutinesAsyncWork(tester);

      await scrollUntilBuilt(tester, find.text('Weekly meeting'));

      final allText = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .join('\n');

      expect(allText, isNot(contains('Weekly ? Wednesday')));
      expect(allText, contains('Weekly \u00b7 Wednesday'));
    },
  );
}
