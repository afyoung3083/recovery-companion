import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_data_ownership_repository.dart';
import 'package:mobile/local_recovery_store.dart';
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
  late MemorySecureKeyValueStore keyStore;
  late LocalRecoveryStore store;
  late LocalDataOwnershipRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_data_ownership_test_',
    );

    keyStore = MemorySecureKeyValueStore();

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}'
        '${Platform.pathSeparator}'
        'recovery_data.enc',
      ),
      keyStore: keyStore,
    );

    repository = LocalDataOwnershipRepository(
      store: store,
      now: () => DateTime.utc(2026, 8, 27, 18, 30),
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('exports authoritative local recovery data', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'journal_entries': [
        {'id': 1, 'text': 'Export me'},
      ],
    });

    final result = await repository.exportRecoveryData();

    final export = result['export'] as Map;

    final metadata = export['metadata'] as Map;

    final data = export['data'] as Map;

    expect(metadata['created_at'], '2026-08-27T18:30:00.000Z');

    expect(metadata['source'], 'local_device');

    expect(metadata['sha256'].toString().length, 64);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');

    expect(
      ((data['journal_entries'] as List).first as Map)['text'],
      'Export me',
    );
  });

  test('export does not modify authoritative data', () async {
    await store.write({
      'goals': [
        {'id': 1, 'text': 'Keep goal'},
      ],
    });

    final before = await store.read();

    await repository.exportRecoveryData();

    final after = await store.read();

    expect(after['data'], before['data']);
  });

  test('encrypted file does not contain exported plaintext', () async {
    await store.write({
      'journal_entries': [
        {'id': 1, 'text': 'Private export content'},
      ],
    });

    await repository.exportRecoveryData();

    final encrypted = await store.dataFile.readAsString();

    expect(encrypted, isNot(contains('Private export content')));
  });

  test('permanent deletion removes local data and encryption key', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
    });

    expect(await store.exists, isTrue);

    expect(keyStore.values[LocalRecoveryStore.encryptionKeyName], isNotNull);

    await repository.deleteRecoveryData(
      confirmation: 'DELETE MY RECOVERY DATA',
    );

    expect(await store.exists, isFalse);

    expect(keyStore.values[LocalRecoveryStore.encryptionKeyName], isNull);

    final empty = await store.read();

    expect(empty['data'], isEmpty);
  });

  test('wrong deletion phrase does not alter data', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
    });

    expect(
      () => repository.deleteRecoveryData(confirmation: 'DELETE'),
      throwsArgumentError,
    );

    final document = await store.read();

    expect((document['data'] as Map)['profile'], isNotNull);
  });
}
