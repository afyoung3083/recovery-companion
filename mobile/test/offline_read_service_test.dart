import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:mobile/api_client.dart';
import 'package:mobile/offline_read_service.dart';

void main() {
  test('Network success is returned and cached', () async {
    final cache = MemoryOfflineCacheStore();

    final service = OfflineReadService(
      cache: cache,
      clock: () => DateTime.utc(2026, 8, 25, 12),
    );

    final result = await service.read(
      cacheKey: 'dashboard',
      networkRead: () async {
        return {
          'dashboard_data': {'sobriety_days': 365},
        };
      },
    );

    expect(result.source, OfflineReadSource.network);

    expect(result.isCached, false);
    expect(result.cachedAt, isNull);

    final cached = await cache.read('dashboard');

    expect(cached, isNotNull);

    expect(cached!.data['dashboard_data'], {'sobriety_days': 365});

    expect(cached.cachedAt, DateTime.utc(2026, 8, 25, 12));
  });

  test('Connectivity failure uses cached data', () async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      'dashboard',
      OfflineCacheEntry(
        data: {
          'dashboard_data': {'sobriety_days': 364},
        },
        cachedAt: DateTime.utc(2026, 8, 24, 12),
      ),
    );

    final service = OfflineReadService(cache: cache);

    final result = await service.read(
      cacheKey: 'dashboard',
      networkRead: () async {
        throw http.ClientException('Connection failed');
      },
    );

    expect(result.isCached, true);

    expect(result.cachedAt, DateTime.utc(2026, 8, 24, 12));

    expect(result.data['dashboard_data'], {'sobriety_days': 364});
  });

  test('Timeout uses cached data', () async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      'profile',
      OfflineCacheEntry(
        data: {
          'profile': {'sobriety_date': '2025-08-12'},
        },
        cachedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    final service = OfflineReadService(cache: cache);

    final result = await service.read(
      cacheKey: 'profile',
      networkRead: () async {
        throw TimeoutException('Timed out');
      },
    );

    expect(result.isCached, true);
  });

  test('Temporary server failure uses cached data', () async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      'goals',
      OfflineCacheEntry(
        data: {'goals': []},
        cachedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    final service = OfflineReadService(cache: cache);

    final result = await service.read(
      cacheKey: 'goals',
      networkRead: () async {
        throw const ApiException('Unavailable', statusCode: 503);
      },
    );

    expect(result.isCached, true);
  });

  test('Authentication failure never uses cached recovery data', () async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      'dashboard',
      OfflineCacheEntry(
        data: {
          'dashboard_data': {'sobriety_days': 365},
        },
        cachedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    final service = OfflineReadService(cache: cache);

    expect(
      () => service.read(
        cacheKey: 'dashboard',
        networkRead: () async {
          throw const ApiException('Unauthorized', statusCode: 401);
        },
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('Client error never uses cached recovery data', () async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      'dashboard',
      OfflineCacheEntry(
        data: {'dashboard_data': {}},
        cachedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    final service = OfflineReadService(cache: cache);

    expect(
      () => service.read(
        cacheKey: 'dashboard',
        networkRead: () async {
          throw const ApiException('Bad request', statusCode: 400);
        },
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('Recoverable failure without cache rethrows', () async {
    final service = OfflineReadService(cache: MemoryOfflineCacheStore());

    expect(
      () => service.read(
        cacheKey: 'journal',
        networkRead: () async {
          throw http.ClientException('Offline');
        },
      ),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('Failure classification is conservative', () {
    expect(
      canUseCachedDataFor(const ApiException('Unauthorized', statusCode: 403)),
      false,
    );

    expect(
      canUseCachedDataFor(const ApiException('Not found', statusCode: 404)),
      false,
    );

    expect(
      canUseCachedDataFor(
        const ApiException('Too many requests', statusCode: 429),
      ),
      true,
    );

    expect(
      canUseCachedDataFor(
        const ApiException('Gateway timeout', statusCode: 504),
      ),
      true,
    );
  });
}
