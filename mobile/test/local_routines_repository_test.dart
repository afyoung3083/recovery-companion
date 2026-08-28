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

    repository = LocalRoutinesRepository(store: store);
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

    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    final storedRoutine = (data['routines'] as List).first as Map;

    expect(storedRoutine['active'], isFalse);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');

    expect(((data['goals'] as List).first as Map)['text'], 'Keep this goal');
  });
}
