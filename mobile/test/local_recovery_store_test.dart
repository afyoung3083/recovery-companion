import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/recovery_backup_protector.dart';
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

  test('new write invokes backup protection after file creation', () async {
    final protector = RecordingRecoveryBackupProtector();
    final store = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
      backupProtector: protector,
    );

    await store.write({'value': 'protected'});

    expect(protector.calls, 1);
    expect(protector.paths, [dataFile.path]);
    expect(await dataFile.exists(), isTrue);
  });

  test('rewrite invokes backup protection again for the authoritative file',
      () async {
    final protector = RecordingRecoveryBackupProtector();
    final store = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
      backupProtector: protector,
    );

    await store.write({'value': 'first'});
    await store.write({'value': 'second'});

    expect(protector.calls, 2);
    expect(protector.paths, [dataFile.path, dataFile.path]);
  });

  test('existing file receives backup protection during read', () async {
    final protector = RecordingRecoveryBackupProtector();
    final initialStore = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
      backupProtector: protector,
    );

    await initialStore.write({'status': 'ready'});
    expect(protector.calls, 1);

    final reopenedStore = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
      backupProtector: protector,
    );

    await reopenedStore.read();

    expect(protector.calls, 2);
    expect(protector.paths.last, dataFile.path);
  });

  test('write keeps data committed when backup protection fails', () async {
    final failingProtector = FailingRecoveryBackupProtector();
    final store = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
      backupProtector: failingProtector,
    );

    await store.write({'value': 'committed'});

    expect(await dataFile.exists(), isTrue);
    expect(store.backupProtectionIssue, isNotNull);
    expect(store.backupProtectionIssue!.code, 'BACKUP_PROTECTION_FAILED');
    expect(store.backupProtectionIssue!.message, isNot(contains(dataFile.path)));

    final document = await store.read();
    expect((document['data'] as Map)['value'], 'committed');
  });

  test('read continues with valid data when backup protection fails', () async {
    final successfulProtector = RecordingRecoveryBackupProtector();
    final initialStore = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
      backupProtector: successfulProtector,
    );

    await initialStore.write({'value': 'keep-me'});

    final failingProtector = FailingRecoveryBackupProtector();
    final store = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
      backupProtector: failingProtector,
    );

    final document = await store.read();
    expect((document['data'] as Map)['value'], 'keep-me');
    expect(store.backupProtectionIssue, isNotNull);
    expect(store.backupProtectionIssue!.message, isNot(contains(dataFile.path)));
  });

  test('successful later protection clears a previous issue', () async {
    final failingProtector = FailingRecoveryBackupProtector();
    final store = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
      backupProtector: failingProtector,
    );

    await store.write({'value': 'first'});
    expect(store.backupProtectionIssue, isNotNull);

    final recoveringProtector = RecordingRecoveryBackupProtector();
    final recoveredStore = LocalRecoveryStore(
      dataFile: dataFile,
      keyStore: keyStore,
      backupProtector: recoveringProtector,
    );

    await recoveredStore.read();
    expect(recoveredStore.backupProtectionIssue, isNull);
  });
}

class RecordingRecoveryBackupProtector implements RecoveryBackupProtector {
  final List<String> paths = <String>[];
  int calls = 0;

  @override
  Future<void> protectFile(String filePath) async {
    calls += 1;
    paths.add(filePath);
  }
}

class FailingRecoveryBackupProtector implements RecoveryBackupProtector {
  @override
  Future<void> protectFile(String filePath) async {
    throw const RecoveryBackupProtectionException(
      'Backup exclusion could not be enforced.',
    );
  }
}
