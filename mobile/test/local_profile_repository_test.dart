import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_profile_repository.dart';
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
  late LocalRecoveryStore store;
  late LocalProfileRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_profile_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}${Platform.pathSeparator}recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    repository = LocalProfileRepository(store: store);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('starts with empty profile', () async {
    final result = await repository.getProfile();

    expect(result['profile'], isEmpty);
  });

  test('saves and reloads sobriety date locally', () async {
    await repository.updateSobrietyDate('2026-08-12');

    final result = await repository.getProfile();

    expect((result['profile'] as Map)['sobriety_date'], '2026-08-12');
  });

  test('sobriety date is encrypted at rest', () async {
    await repository.updateSobrietyDate('2026-08-12');

    final encrypted = await store.dataFile.readAsString();

    expect(encrypted, isNot(contains('2026-08-12')));
  });

  test('profile update preserves other recovery data', () async {
    await store.write({
      'daily_checkins': {
        '2026-08-27': {'meeting': true},
      },
      'journal_entries': [
        {'id': 1, 'text': 'Keep this entry'},
      ],
    });

    await repository.updateSobrietyDate('2026-08-12');

    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['daily_checkins'] as Map)['2026-08-27'], isNotNull);

    expect(
      ((data['journal_entries'] as List).first as Map)['text'],
      'Keep this entry',
    );

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');
  });
}
