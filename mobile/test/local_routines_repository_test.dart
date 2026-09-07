import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/local_routines_repository.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(values);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

void main() {
  late Directory directory;
  late LocalRecoveryStore store;
  late LocalRoutinesRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_routines_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}'
        '${Platform.pathSeparator}'
        'recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    repository = LocalRoutinesRepository(
      store: store,
      now: () => DateTime.utc(2026, 9, 6, 12, 30),
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('starts with no active routines', () async {
    final result = await repository.getRoutines();

    expect(result['routines'], isEmpty);
  });

  test('creates and reloads encrypted routine locally', () async {
    await repository.createRoutine(
      text: 'Call sponsor every morning',
      area: 'connection',
      frequency: 'daily',
    );

    final result = await repository.getRoutines();

    final routines = result['routines'] as List;

    final routine = routines.first as Map;

    expect(routines.length, 1);
    expect(routine['id'], 1);
    expect(routine['text'], 'Call sponsor every morning');
    expect(routine['area'], 'connection');
    expect(routine['frequency'], 'daily');
    expect(routine['day_of_week'], '');

    final encrypted = await store.dataFile.readAsString();

    expect(encrypted, isNot(contains('Call sponsor every morning')));
  });

  test('weekly routine retains selected day', () async {
    await repository.createRoutine(
      text: 'Attend home group',
      area: 'meetings',
      frequency: 'weekly',
      dayOfWeek: 'thursday',
    );

    final result = await repository.getRoutines();

    final routine = (result['routines'] as List).first as Map;

    expect(routine['frequency'], 'weekly');

    expect(routine['day_of_week'], 'thursday');
  });

  test(
    'updates routine fields and preserves identity and unknown data',
    () async {
      await store.write({
        'profile': {'sobriety_date': '2026-08-12'},
        'routines': [
          {
            'id': 3,
            'text': 'Original routine',
            'area': 'prayer',
            'frequency': 'daily',
            'day_of_week': '',
            'active': false,
            'created_at': '2026-08-20T12:00:00Z',
            'unknown_field': 'preserve me',
          },
          {'id': 4, 'text': 'Other routine', 'active': true},
        ],
      });

      final result = await repository.updateRoutine(
        routineId: 3,
        text: 'Updated routine',
        area: 'meetings',
        frequency: 'weekly',
        dayOfWeek: 'thursday',
      );
      final routine = result['routine'] as Map;

      expect(routine['id'], 3);
      expect(routine['text'], 'Updated routine');
      expect(routine['area'], 'meetings');
      expect(routine['frequency'], 'weekly');
      expect(routine['day_of_week'], 'thursday');
      expect(routine['active'], isFalse);
      expect(routine['created_at'], '2026-08-20T12:00:00Z');
      expect(routine['updated_at'], '2026-09-06T12:30:00.000Z');
      expect(routine['unknown_field'], 'preserve me');

      final inactive = await repository.getInactiveRoutines();
      expect((inactive.single)['id'], 3);
      expect((await repository.getRoutines())['routines'], hasLength(1));
      expect(
        ((await repository.getRoutines())['routines'] as List).single['id'],
        4,
      );

      final data = (await store.read())['data'] as Map;
      expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');
    },
  );

  test('daily update clears day of week consistently', () async {
    final created = await repository.createRoutine(
      text: 'Weekly routine',
      area: 'service',
      frequency: 'weekly',
      dayOfWeek: 'monday',
    );
    final id = (created['routine'] as Map)['id'] as int;

    final result = await repository.updateRoutine(
      routineId: id,
      text: 'Daily routine',
      area: 'service',
      frequency: 'daily',
      dayOfWeek: 'friday',
    );

    expect((result['routine'] as Map)['frequency'], 'daily');
    expect((result['routine'] as Map)['day_of_week'], isEmpty);
  });

  test('missing routine update fails without modifying storage', () async {
    await repository.createRoutine(
      text: 'Existing routine',
      area: 'other',
      frequency: 'daily',
    );
    final before = await store.dataFile.readAsString();

    expect(
      () => repository.updateRoutine(
        routineId: 999,
        text: 'Missing',
        area: 'other',
        frequency: 'daily',
        dayOfWeek: 'sunday',
      ),
      throwsA(isA<StateError>()),
    );
    expect(await store.dataFile.readAsString(), before);
  });

  test('deactivating routine removes it from active routines and preserves other data', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'goals': [
        {'id': 1, 'text': 'Keep this goal', 'active': true},
      ],
    });

    final created = await repository.createRoutine(
      text: 'Daily prayer',
      area: 'prayer',
      frequency: 'daily',
    );

    final id = (created['routine'] as Map)['id'] as int;

    await repository.setRoutineActive(routineId: id, active: false);

    final active = await repository.getRoutines();

    expect(active['routines'], isEmpty);

    final inactive = await repository.getInactiveRoutines();
    final inactiveRoutine = (inactive as List).single as Map;
    expect(inactiveRoutine['id'], id);
    expect(inactiveRoutine['active'], isFalse);
    expect(inactiveRoutine['updated_at'], '2026-09-06T12:30:00.000Z');

    final inactiveDocument = await store.read();
    final inactiveData = Map<String, dynamic>.from(
      inactiveDocument['data'] as Map,
    );
    final storedInactiveRoutine =
        (inactiveData['routines'] as List).first as Map;
    expect(storedInactiveRoutine['active'], isFalse);

    await repository.setRoutineActive(routineId: id, active: true);

    final reactivated = (await repository.getRoutines())['routines'] as List;
    expect(reactivated.single['id'], id);
    expect(await repository.getInactiveRoutines(), isEmpty);

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final storedRoutine = (data['routines'] as List).first as Map;
    expect(storedRoutine['active'], isTrue);
    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');
    expect(((data['goals'] as List).first as Map)['text'], 'Keep this goal');
  });

  test(
    'legacy routine missing active remains active and reads do not mutate',
    () async {
      await store.write({
        'routines': [
          {'id': 8, 'text': 'Legacy routine', 'unknown_field': 'keep'},
        ],
      });
      final before = await store.dataFile.readAsString();

      final active = (await repository.getRoutines())['routines'] as List;
      expect(active.single['id'], 8);
      expect((await repository.getInactiveRoutines()), isEmpty);

      expect(await store.dataFile.readAsString(), before);
    },
  );

  test('toggling active preserves id and unknown fields', () async {
    await store.write({
      'routines': [
        {
          'id': 11,
          'text': 'Weekend service',
          'area': 'service',
          'frequency': 'weekly',
          'day_of_week': 'saturday',
          'active': true,
          'created_at': '2026-08-15T09:00:00Z',
          'unknown_field': 'keep me',
        },
      ],
    });

    await repository.setRoutineActive(routineId: 11, active: false);
    final inactive = (await repository.getInactiveRoutines()).single;
    expect(inactive['id'], 11);
    expect(inactive['unknown_field'], 'keep me');

    await repository.setRoutineActive(routineId: 11, active: true);
    final active =
        ((await repository.getRoutines())['routines'] as List).single as Map;
    expect(active['id'], 11);
    expect(active['unknown_field'], 'keep me');
  });
}
