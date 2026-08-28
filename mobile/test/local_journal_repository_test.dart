import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_journal_repository.dart';
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
  late LocalJournalRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_journal_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}${Platform.pathSeparator}recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    repository = LocalJournalRepository(
      store: store,
      now: () => DateTime.utc(2026, 8, 27, 18, 30),
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('starts with no journal entries', () async {
    final result = await repository.getEntries();
    expect(result['entries'], isEmpty);
  });

  test('creates and reloads encrypted journal entry', () async {
    await repository.createEntry(
      text: 'Called my sponsor and stayed connected.',
      tags: ['connection', 'sponsor'],
    );

    final result = await repository.getEntries();
    final entries = result['entries'] as List;
    final entry = entries.first as Map;

    expect(entries.length, 1);
    expect(entry['id'], 1);
    expect(entry['text'], 'Called my sponsor and stayed connected.');
    expect(entry['tags'], ['connection', 'sponsor']);
    expect(entry['date'], '2026-08-27');

    final encrypted = await store.dataFile.readAsString();
    expect(encrypted, isNot(contains('Called my sponsor')));
  });

  test('assigns increasing local entry IDs', () async {
    await repository.createEntry(text: 'First', tags: []);
    await repository.createEntry(text: 'Second', tags: []);

    final result = await repository.getEntries();
    final entries = result['entries'] as List;
    final ids = entries.map((entry) => (entry as Map)['id']).toSet();

    expect(ids, {1, 2});
  });

  test('searches journal text and tags locally', () async {
    await repository.createEntry(
      text: 'Met with recovery friends.',
      tags: ['meeting'],
    );

    await repository.createEntry(
      text: 'Quiet morning prayer.',
      tags: ['gratitude'],
    );

    final byText = await repository.search('friends');
    final byTag = await repository.search('gratitude');

    expect((byText['entries'] as List).length, 1);
    expect((byTag['entries'] as List).length, 1);
    expect(
      ((byTag['entries'] as List).first as Map)['text'],
      'Quiet morning prayer.',
    );
  });

  test('preserves other authoritative recovery data', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'daily_checkins': {
        '2026-08-27': {'meeting': true},
      },
    });

    await repository.createEntry(text: 'Journal entry', tags: []);

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');
    expect((data['daily_checkins'] as Map)['2026-08-27'], isNotNull);
    expect(data['journal_entries'], isA<List>());
  });
}
