import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_goals_repository.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<Map<String, String>> readAll() async =>
      Map<String, String>.from(values);

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

void main() {
  late Directory directory;
  late LocalRecoveryStore store;
  late LocalGoalsRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_goals_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}${Platform.pathSeparator}recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    repository = LocalGoalsRepository(store: store);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('starts with no active goals', () async {
    final result = await repository.getGoals();
    expect(result['goals'], isEmpty);
  });

  test('loads active goals without changing their fields', () async {
    await store.write({
      'goals': [
        {
          'id': 7,
          'text': 'Call sponsor',
          'active': true,
          'completed': false,
          'custom_field': 'preserve me',
        },
      ],
    });

    final result = await repository.getGoals();
    final goal = (result['goals'] as List).single as Map;

    expect(goal['id'], 7);
    expect(goal['text'], 'Call sponsor');
    expect(goal['custom_field'], 'preserve me');
  });

  test('creates and reloads goal locally', () async {
    await repository.createGoal(
      text: 'Call sponsor three times this week',
      area: 'connection',
      targetDate: '2026-09-01',
    );

    final result = await repository.getGoals();
    final goals = result['goals'] as List;
    final goal = goals.first as Map;

    expect(goals.length, 1);
    expect(goal['id'], 1);
    expect(goal['text'], 'Call sponsor three times this week');
    expect(goal['area'], 'connection');
    expect(goal['target_date'], '2026-09-01');

    final encrypted = await store.dataFile.readAsString();
    expect(encrypted, isNot(contains('Call sponsor')));
  });

  test('completing goal removes it from active goals', () async {
    final created = await repository.createGoal(
      text: 'Attend meeting',
      area: 'meetings',
    );

    final id = (created['goal'] as Map)['id'] as int;

    await repository.completeGoal(id);

    final active = await repository.getGoals();
    expect(active['goals'], isEmpty);

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);
    final savedGoal = (data['goals'] as List).first as Map;

    expect(savedGoal['completed'], isTrue);
    expect(savedGoal['active'], isFalse);
  });

  test(
    'updates active goal fields without changing lifecycle or identity',
    () async {
      await store.write({
        'goals': [
          {
            'id': 4,
            'text': 'Original active goal',
            'area': 'health',
            'target_date': '2026-09-10',
            'active': true,
            'completed': false,
            'created_at': '2026-08-20T12:00:00Z',
            'unknown_field': 'preserve me',
          },
          {'id': 5, 'text': 'Other goal', 'active': true, 'completed': false},
        ],
        'profile': {'sobriety_date': '2026-08-12'},
      });

      final result = await repository.updateGoal(
        goalId: 4,
        text: 'Updated active goal',
        area: 'connection',
        targetDate: '2026-09-20',
      );

      final goal = result['goal'] as Map;
      expect(goal['id'], 4);
      expect(goal['text'], 'Updated active goal');
      expect(goal['area'], 'connection');
      expect(goal['target_date'], '2026-09-20');
      expect(goal['active'], isTrue);
      expect(goal['completed'], isFalse);
      expect(goal['created_at'], '2026-08-20T12:00:00Z');
      expect(goal['unknown_field'], 'preserve me');

      final active = (await repository.getGoals())['goals'] as List;
      expect(
        (active.firstWhere((item) => (item as Map)['id'] == 5) as Map)['text'],
        'Other goal',
      );
      expect(
        (active.firstWhere((item) => (item as Map)['id'] == 4) as Map)['text'],
        'Updated active goal',
      );

      final data = (await store.read())['data'] as Map;
      expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');
    },
  );

  test('updates completed goal fields without reactivating it', () async {
    await store.write({
      'goals': [
        {
          'id': 6,
          'text': 'Original completed goal',
          'area': 'meetings',
          'target_date': '2026-09-01',
          'active': false,
          'completed': true,
          'created_at': '2026-08-21T12:00:00Z',
          'completed_at': '2026-08-30T18:00:00Z',
          'unknown_field': 'keep this',
        },
      ],
    });

    final result = await repository.updateGoal(
      goalId: 6,
      text: 'Corrected completed goal',
      area: 'connection',
      targetDate: '',
    );

    final goal = result['goal'] as Map;
    expect(goal['id'], 6);
    expect(goal['text'], 'Corrected completed goal');
    expect(goal['area'], 'connection');
    expect(goal['target_date'], isEmpty);
    expect(goal['active'], isFalse);
    expect(goal['completed'], isTrue);
    expect(goal['created_at'], '2026-08-21T12:00:00Z');
    expect(goal['completed_at'], '2026-08-30T18:00:00Z');
    expect(goal['unknown_field'], 'keep this');

    expect((await repository.getGoals())['goals'], isEmpty);
    expect(
      ((await repository.getCompletedGoals())['goals'] as List).single,
      goal,
    );
  });

  test('missing goal update fails without modifying storage', () async {
    await store.write({
      'goals': [
        {'id': 1, 'text': 'Existing goal', 'active': true, 'completed': false},
      ],
    });
    final before = await store.dataFile.readAsString();

    expect(
      () => repository.updateGoal(
        goalId: 999,
        text: 'Should not exist',
        area: 'other',
        targetDate: '',
      ),
      throwsA(isA<StateError>()),
    );

    expect(await store.dataFile.readAsString(), before);
  });

  test('reactivates a completed goal without duplicating it', () async {
    await store.write({
      'goals': [
        {
          'id': 9,
          'text': 'Completed goal',
          'area': 'connection',
          'target_date': '2026-10-01',
          'active': false,
          'completed': true,
          'created_at': '2026-08-22T12:00:00Z',
          'completed_at': '2026-08-31T18:00:00Z',
          'unknown_field': 'preserve me',
        },
      ],
    });

    final result = await repository.reactivateGoal(9);
    final goal = result['goal'] as Map;

    expect(goal['id'], 9);
    expect(goal['active'], isTrue);
    expect(goal['completed'], isFalse);
    expect(goal.containsKey('completed_at'), isFalse);
    expect(goal['text'], 'Completed goal');
    expect(goal['area'], 'connection');
    expect(goal['target_date'], '2026-10-01');
    expect(goal['created_at'], '2026-08-22T12:00:00Z');
    expect(goal['unknown_field'], 'preserve me');

    final active = (await repository.getGoals())['goals'] as List;
    final completed = (await repository.getCompletedGoals())['goals'] as List;
    expect(active, hasLength(1));
    expect((active.single as Map)['id'], 9);
    expect(completed, isEmpty);
  });

  test('missing goal reactivation fails without modifying storage', () async {
    await store.write({
      'goals': [
        {'id': 1, 'text': 'Existing goal', 'active': true, 'completed': false},
      ],
    });
    final before = await store.dataFile.readAsString();

    expect(() => repository.reactivateGoal(999), throwsA(isA<StateError>()));

    expect(await store.dataFile.readAsString(), before);
  });

  test('completed goals remain available in completed history', () async {
    final created = await repository.createGoal(
      text: 'Attend meeting',
      area: 'meetings',
    );

    final id = (created['goal'] as Map)['id'] as int;

    await repository.completeGoal(id);

    final completed = await repository.getCompletedGoals();
    final goals = completed['goals'] as List;

    expect(goals.length, 1);
    expect((goals.single as Map)['id'], id);
    expect((goals.single as Map)['completed'], isTrue);
  });

  test(
    'categorizes legacy active and completed flag combinations safely',
    () async {
      await store.write({
        'goals': [
          {'id': 1, 'text': 'Active flags', 'active': true, 'completed': false},
          {
            'id': 2,
            'text': 'Inactive flags',
            'active': false,
            'completed': true,
          },
          {'id': 3, 'text': 'Inactive without completed flag', 'active': false},
          {'id': 4, 'text': 'Completed without active flag', 'completed': true},
          {'id': 5, 'text': 'Missing flags'},
        ],
      });

      final active = await repository.getGoals();
      final completed = await repository.getCompletedGoals();

      expect(
        (active['goals'] as List).map((goal) => (goal as Map)['id']).toList(),
        [1, 5],
      );
      expect(
        (completed['goals'] as List)
            .map((goal) => (goal as Map)['id'])
            .toList(),
        [2, 3, 4],
      );

      final document = await store.read();
      final savedGoals = (document['data'] as Map)['goals'] as List;
      expect((savedGoals[2] as Map)['text'], 'Inactive without completed flag');
    },
  );

  test('goal changes preserve other recovery data', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'journal_entries': [
        {'id': 1, 'text': 'Keep me'},
      ],
    });

    await repository.createGoal(text: 'Recovery goal', area: 'other');

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');
    expect(((data['journal_entries'] as List).first as Map)['text'], 'Keep me');
  });

  test('deleting an active goal removes only that goal', () async {
    await store.write({
      'goals': [
        {'id': 1, 'text': 'Keep this one', 'active': true, 'completed': false},
        {
          'id': 2,
          'text': 'Delete this one',
          'active': true,
          'completed': false,
        },
        {'id': 3, 'text': 'Keep this too', 'active': true, 'completed': false},
      ],
    });

    await repository.deleteGoal(2);

    final active = await repository.getGoals();
    final ids = (active['goals'] as List)
        .map((goal) => (goal as Map)['id'])
        .toList();

    expect(ids, [1, 3]);
  });

  test('deleting a goal preserves unknown fields on other records', () async {
    await store.write({
      'goals': [
        {'id': 1, 'text': 'Delete me', 'active': true, 'completed': false},
        {
          'id': 2,
          'text': 'Preserve me',
          'active': true,
          'completed': false,
          'unexpected_field': 'kept',
        },
      ],
    });

    await repository.deleteGoal(1);

    final document = await store.read();
    final savedGoals = (document['data'] as Map)['goals'] as List;

    expect(savedGoals.length, 1);
    expect((savedGoals.single as Map)['unexpected_field'], 'kept');
  });

  test('deleting a goal preserves unrelated recovery data', () async {
    await store.write({
      'goals': [
        {'id': 1, 'text': 'Delete me', 'active': true, 'completed': false},
      ],
      'profile': {'sobriety_date': '2026-08-12'},
      'journal_entries': [
        {'id': 1, 'text': 'Keep me'},
      ],
    });

    await repository.deleteGoal(1);

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['goals'] as List), isEmpty);
    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');
    expect(((data['journal_entries'] as List).first as Map)['text'], 'Keep me');
  });

  test('missing goal deletion fails without modifying storage', () async {
    await store.write({
      'goals': [
        {'id': 1, 'text': 'Existing goal', 'active': true, 'completed': false},
      ],
    });
    final before = await store.dataFile.readAsString();

    expect(() => repository.deleteGoal(999), throwsA(isA<StateError>()));

    expect(await store.dataFile.readAsString(), before);
  });
}
