import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  late Directory tempDirectory;
  late File dataFile;
  late MemorySecureKeyValueStore keyStore;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'recovery_companion_local_store_test_',
    );

    dataFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}recovery_data.enc',
    );

    keyStore = MemorySecureKeyValueStore();
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('missing file returns an empty recovery document', () async {
    final store = LocalRecoveryStore(dataFile: dataFile, keyStore: keyStore);

    final document = await store.read();

    expect(document['schema_version'], 1);
    expect(document['updated_at'], isNull);
    expect(document['data'], isEmpty);
    expect(await dataFile.exists(), isFalse);
  });

  test('writes and reads encrypted authoritative recovery data', () async {
    final store = LocalRecoveryStore(dataFile: dataFile, keyStore: keyStore);

    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'journal': [
        {'text': 'Sensitive recovery journal text'},
      ],
    });

    final rawFile = await dataFile.readAsString();

    expect(rawFile, isNot(contains('Sensitive recovery journal text')));

    expect(rawFile, isNot(contains('2026-08-12')));

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');

    expect(
      ((data['journal'] as List).first as Map)['text'],
      'Sensitive recovery journal text',
    );
  });

  test('a second store instance can read using the persisted key', () async {
    final firstStore = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
    );

    await firstStore.write({
      'goals': [
        {'text': 'Stay connected'},
      ],
    });

    final secondStore = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
    );

    final document = await secondStore.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect(((data['goals'] as List).first as Map)['text'], 'Stay connected');
  });

  test('corrupted encrypted data throws without deleting the file', () async {
    final store = LocalRecoveryStore(dataFile: dataFile, keyStore: keyStore);

    await store.write({
      'journal': [
        {'text': 'Keep this data'},
      ],
    });

    await dataFile.writeAsString(
      '{"envelope_version":1,"cipher_text":"corrupted"}',
      flush: true,
    );

    expect(store.read, throwsA(isA<LocalRecoveryStoreCorruptedException>()));

    expect(await dataFile.exists(), isTrue);

    final contents = await dataFile.readAsString();

    expect(contents, '{"envelope_version":1,"cipher_text":"corrupted"}');
  });

  test(
    'missing encryption key never causes existing data to be replaced',
    () async {
      final store = LocalRecoveryStore(dataFile: dataFile, keyStore: keyStore);

      await store.write({
        'daily_checkins': {
          '2026-08-27': {'meeting': true},
        },
      });

      final originalContents = await dataFile.readAsString();

      keyStore.values.clear();

      expect(
        store.read,
        throwsA(isA<LocalRecoveryStoreKeyUnavailableException>()),
      );

      expect(
        () => store.write({'replacement': true}),
        throwsA(isA<LocalRecoveryStoreKeyUnavailableException>()),
      );

      expect(await dataFile.readAsString(), originalContents);
    },
  );

  test('deleteAll removes recovery data and its encryption key', () async {
    final store = LocalRecoveryStore(dataFile: dataFile, keyStore: keyStore);

    await store.write({
      'journal': [
        {'text': 'Delete me'},
      ],
    });

    expect(await dataFile.exists(), isTrue);
    expect(keyStore.values[LocalRecoveryStore.encryptionKeyName], isNotNull);

    await store.deleteAll();

    expect(await dataFile.exists(), isFalse);
    expect(keyStore.values[LocalRecoveryStore.encryptionKeyName], isNull);

    final emptyDocument = await store.read();

    expect(emptyDocument['data'], isEmpty);
  });

  test('subsequent writes replace the document safely', () async {
    final store = LocalRecoveryStore(dataFile: dataFile, keyStore: keyStore);

    await store.write({'value': 'first'});

    await store.write({'value': 'second'});

    final document = await store.read();

    expect((document['data'] as Map)['value'], 'second');

    expect(await File('${dataFile.path}.bak').exists(), isFalse);

    expect(await File('${dataFile.path}.tmp').exists(), isFalse);
  });
}
