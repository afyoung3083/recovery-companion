import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/local_step_work_repository.dart';
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
  late LocalStepWorkRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_step_work_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}${Platform.pathSeparator}recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    repository = LocalStepWorkRepository(store: store);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('defaults to Step 1 with no assignments', () async {
    final result = await repository.getStepWork();
    final stepWork = result['step_work'] as Map;

    expect(stepWork['current_step'], 1);
    expect(stepWork['assignments'], isEmpty);
  });

  test('changes and reloads current Step', () async {
    await repository.setCurrentStep(4);

    final result = await repository.getStepWork();

    expect((result['step_work'] as Map)['current_step'], 4);
  });

  test('creates encrypted assignment for current Step', () async {
    await repository.setCurrentStep(4);

    await repository.createAssignment('Write resentment inventory');

    final result = await repository.getStepWork();
    final stepWork = result['step_work'] as Map;
    final assignment = (stepWork['assignments'] as List).first as Map;

    expect(assignment['id'], 1);
    expect(assignment['step'], 4);
    expect(assignment['text'], 'Write resentment inventory');
    expect(assignment['completed'], isFalse);

    final encrypted = await store.dataFile.readAsString();

    expect(encrypted, isNot(contains('Write resentment inventory')));
  });

  test('completes assignment locally', () async {
    final created = await repository.createAssignment(
      'Call sponsor about Step work',
    );

    final id = (created['assignment'] as Map)['id'] as int;

    await repository.completeAssignment(id);

    final result = await repository.getStepWork();
    final stepWork = result['step_work'] as Map;
    final assignment = (stepWork['assignments'] as List).first as Map;

    expect(assignment['completed'], isTrue);
  });

  test('Step Work changes preserve other recovery data', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'goals': [
        {'id': 1, 'text': 'Keep this goal'},
      ],
      'fellowship_contacts': [
        {'id': 1, 'handle': 'Keep this contact'},
      ],
    });

    await repository.setCurrentStep(5);
    await repository.createAssignment('Complete Step 5 assignment');

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');

    expect(((data['goals'] as List).first as Map)['text'], 'Keep this goal');

    expect(
      ((data['fellowship_contacts'] as List).first as Map)['handle'],
      'Keep this contact',
    );
  });
}
