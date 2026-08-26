import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'offline_read_service.dart';

abstract class SecureKeyValueStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }
}

class SecureOfflineCacheStore implements OfflineCacheStore {
  SecureOfflineCacheStore({required this.storage});

  static const int schemaVersion = 1;

  static const String namespace = 'recovery_companion.offline_cache.v1';

  final SecureKeyValueStore storage;

  @override
  Future<OfflineCacheEntry?> read(String key) async {
    final storageKey = _storageKey(key);

    final encoded = await storage.read(key: storageKey);

    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);

      if (decoded is! Map<String, dynamic>) {
        await storage.delete(key: storageKey);
        return null;
      }

      if (decoded['schema_version'] != schemaVersion) {
        await storage.delete(key: storageKey);
        return null;
      }

      final cachedAtRaw = decoded['cached_at'];

      final dataRaw = decoded['data'];

      if (cachedAtRaw is! String || dataRaw is! Map) {
        await storage.delete(key: storageKey);
        return null;
      }

      final cachedAt = DateTime.tryParse(cachedAtRaw);

      if (cachedAt == null) {
        await storage.delete(key: storageKey);
        return null;
      }

      return OfflineCacheEntry(
        data: Map<String, dynamic>.from(dataRaw),
        cachedAt: cachedAt,
      );
    } on FormatException {
      await storage.delete(key: storageKey);
      return null;
    }
  }

  @override
  Future<void> write(String key, OfflineCacheEntry entry) {
    final encoded = jsonEncode({
      'schema_version': schemaVersion,
      'cached_at': entry.cachedAt.toUtc().toIso8601String(),
      'data': entry.data,
    });

    return storage.write(key: _storageKey(key), value: encoded);
  }

  @override
  Future<void> remove(String key) {
    return storage.delete(key: _storageKey(key));
  }

  String _storageKey(String key) {
    return '$namespace.$key';
  }
}
