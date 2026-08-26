import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/offline_read_service.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  final List<String> deletedKeys = <String>[];

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    deletedKeys.add(key);
    values.remove(key);
  }
}

void main() {
  test('Secure cache round-trips recovery data', () async {
    final storage = FakeSecureKeyValueStore();

    final cache = SecureOfflineCacheStore(storage: storage);

    final cachedAt = DateTime.utc(2026, 8, 25, 18, 30);

    await cache.write(
      'dashboard',
      OfflineCacheEntry(
        data: {
          'dashboard_data': {'sobriety_days': 365},
        },
        cachedAt: cachedAt,
      ),
    );

    final restored = await cache.read('dashboard');

    expect(restored, isNotNull);

    expect(restored!.cachedAt, cachedAt);

    expect(restored.data['dashboard_data'], {'sobriety_days': 365});
  });

  test('Secure cache uses a versioned namespace', () async {
    final storage = FakeSecureKeyValueStore();

    final cache = SecureOfflineCacheStore(storage: storage);

    await cache.write(
      'journal',
      OfflineCacheEntry(
        data: {'entries': []},
        cachedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    expect(
      storage.values.keys,
      contains(
        'recovery_companion.'
        'offline_cache.v1.journal',
      ),
    );

    final encoded =
        storage.values['recovery_companion.'
            'offline_cache.v1.journal']!;

    final decoded = jsonDecode(encoded) as Map<String, dynamic>;

    expect(decoded['schema_version'], 1);
  });

  test('Corrupt secure cache is discarded', () async {
    final storage = FakeSecureKeyValueStore();

    const key =
        'recovery_companion.'
        'offline_cache.v1.dashboard';

    storage.values[key] = '{not valid json';

    final cache = SecureOfflineCacheStore(storage: storage);

    final restored = await cache.read('dashboard');

    expect(restored, isNull);

    expect(storage.deletedKeys, contains(key));
  });

  test('Wrong cache schema is discarded', () async {
    final storage = FakeSecureKeyValueStore();

    const key =
        'recovery_companion.'
        'offline_cache.v1.dashboard';

    storage.values[key] = jsonEncode({
      'schema_version': 999,
      'cached_at': DateTime.utc(2026, 8, 25).toIso8601String(),
      'data': {'dashboard_data': {}},
    });

    final cache = SecureOfflineCacheStore(storage: storage);

    final restored = await cache.read('dashboard');

    expect(restored, isNull);

    expect(storage.deletedKeys, contains(key));
  });

  test('Invalid timestamp is discarded', () async {
    final storage = FakeSecureKeyValueStore();

    const key =
        'recovery_companion.'
        'offline_cache.v1.profile';

    storage.values[key] = jsonEncode({
      'schema_version': 1,
      'cached_at': 'not-a-date',
      'data': {'profile': {}},
    });

    final cache = SecureOfflineCacheStore(storage: storage);

    expect(await cache.read('profile'), isNull);

    expect(storage.deletedKeys, contains(key));
  });

  test('Removing cache deletes only its namespaced key', () async {
    final storage = FakeSecureKeyValueStore();

    final cache = SecureOfflineCacheStore(storage: storage);

    await cache.write(
      'goals',
      OfflineCacheEntry(
        data: {'goals': []},
        cachedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    await cache.remove('goals');

    expect(storage.values, isEmpty);

    expect(
      storage.deletedKeys.single,
      'recovery_companion.'
      'offline_cache.v1.goals',
    );
  });
}
