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
}
