import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_client.dart';

enum OfflineReadSource { network, cache }

class OfflineCacheEntry {
  const OfflineCacheEntry({required this.data, required this.cachedAt});

  final Map<String, dynamic> data;
  final DateTime cachedAt;
}

class OfflineReadResult {
  const OfflineReadResult({
    required this.data,
    required this.source,
    this.cachedAt,
  });

  final Map<String, dynamic> data;
  final OfflineReadSource source;
  final DateTime? cachedAt;

  bool get isCached => source == OfflineReadSource.cache;
}

abstract class OfflineCacheStore {
  Future<OfflineCacheEntry?> read(String key);

  Future<void> write(String key, OfflineCacheEntry entry);

  Future<void> remove(String key);
}

class MemoryOfflineCacheStore implements OfflineCacheStore {
  final Map<String, OfflineCacheEntry> _entries = <String, OfflineCacheEntry>{};

  @override
  Future<OfflineCacheEntry?> read(String key) async {
    return _entries[key];
  }

  @override
  Future<void> write(String key, OfflineCacheEntry entry) async {
    _entries[key] = OfflineCacheEntry(
      data: Map<String, dynamic>.from(entry.data),
      cachedAt: entry.cachedAt,
    );
  }

  @override
  Future<void> remove(String key) async {
    _entries.remove(key);
  }
}

class OfflineReadService {
  OfflineReadService({required this.cache, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final OfflineCacheStore cache;
  final DateTime Function() _clock;

  Future<OfflineReadResult> read({
    required String cacheKey,
    required Future<Map<String, dynamic>> Function() networkRead,
  }) async {
    try {
      final data = await networkRead();

      final cachedAt = _clock();

      await cache.write(
        cacheKey,
        OfflineCacheEntry(data: data, cachedAt: cachedAt),
      );

      return OfflineReadResult(data: data, source: OfflineReadSource.network);
    } catch (error) {
      if (!canUseCachedDataFor(error)) {
        rethrow;
      }

      final cached = await cache.read(cacheKey);

      if (cached == null) {
        rethrow;
      }

      return OfflineReadResult(
        data: Map<String, dynamic>.from(cached.data),
        source: OfflineReadSource.cache,
        cachedAt: cached.cachedAt,
      );
    }
  }
}

bool canUseCachedDataFor(Object error) {
  if (error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException) {
    return true;
  }

  if (error is! ApiException) {
    return false;
  }

  final status = error.statusCode;

  if (status == null) {
    return false;
  }

  if (status == 408 || status == 429) {
    return true;
  }

  return status >= 500 && status <= 599;
}
