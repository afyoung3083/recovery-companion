import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/offline_read_service.dart';
import 'package:mobile/profile_screen.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  Widget appFor(
    ApiClient apiClient, {
    OfflineReadService? offlineReadService,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ProfileScreen(
          apiClient: apiClient,
          offlineReadService: offlineReadService,
        ),
      ),
    );
  }

  testWidgets('Profile displays saved sobriety date', (
    tester,
  ) async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/profile');
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'profile': {
            'sobriety_date': '2026-08-12',
          },
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(appFor(apiClient));
    await tester.pumpAndSettle();

    expect(
      find.text('Your Profile'),
      findsOneWidget,
    );

    expect(
      find.byKey(
        const ValueKey(
          'profile-sobriety-card',
        ),
      ),
      findsOneWidget,
    );

    expect(
      find.byKey(
        const ValueKey(
          'profile-sobriety-date',
        ),
      ),
      findsOneWidget,
    );

    expect(
      find.text('2026-08-12'),
      findsOneWidget,
    );

    expect(
      find.text('Change Sobriety Date'),
      findsOneWidget,
    );

    apiClient.close();
  });

  testWidgets(
    'Profile date picker saves selected sobriety date',
    (tester) async {
      var updateCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/profile') {
          return http.Response(
            jsonEncode({
              'profile': {
                'sobriety_date': '2026-08-12',
              },
            }),
            200,
          );
        }

        if (request.method == 'PUT' &&
            request.url.path ==
                '/profile/sobriety-date') {
          updateCount += 1;

          expect(
            request.headers['Authorization'],
            'Bearer $token',
          );

          expect(
            jsonDecode(request.body),
            {
              'sobriety_date':
                  '2026-08-12',
            },
          );

          return http.Response(
            jsonEncode({
              'profile': {
                'sobriety_date':
                    '2026-08-12',
              },
            }),
            200,
          );
        }

        throw StateError(
          'Unexpected request: '
          '${request.method} '
          '${request.url}',
        );
      });

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        appFor(apiClient),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey(
            'profile-change-sobriety-date',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byType(DatePickerDialog),
        findsOneWidget,
      );

      await tester.tap(
        find.text('OK'),
      );

      await tester.pumpAndSettle();

      expect(updateCount, 1);

      expect(
        find.text('2026-08-12'),
        findsOneWidget,
      );

      apiClient.close();
    },
  );

  testWidgets(
    'Online Profile response is cached for offline use',
    (tester) async {
      final cache =
          MemoryOfflineCacheStore();

      final mockClient =
          MockClient((request) async {
        expect(
          request.method,
          'GET',
        );

        expect(
          request.url.path,
          '/profile',
        );

        return http.Response(
          jsonEncode({
            'profile': {
              'sobriety_date':
                  '2025-08-12',
            },
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        appFor(
          apiClient,
          offlineReadService:
              OfflineReadService(
            cache: cache,
            clock: () => DateTime.utc(
              2026,
              8,
              26,
              18,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('2025-08-12'),
        findsOneWidget,
      );

      expect(
        find.text('Offline copy'),
        findsNothing,
      );

      final cached =
          await cache.read('profile');

      expect(
        cached,
        isNotNull,
      );

      expect(
        cached!.cachedAt,
        DateTime.utc(
          2026,
          8,
          26,
          18,
        ),
      );

      expect(
        cached.data['profile'],
        {
          'sobriety_date':
              '2025-08-12',
        },
      );

      apiClient.close();
    },
  );

  testWidgets(
    'Profile remains readable offline and editing is disabled',
    (tester) async {
      final cache =
          MemoryOfflineCacheStore();

      await cache.write(
        'profile',
        OfflineCacheEntry(
          data: {
            'profile': {
              'sobriety_date':
                  '2025-08-12',
            },
          },
          cachedAt: DateTime.utc(
            2026,
            8,
            26,
            17,
            30,
          ),
        ),
      );

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient:
            MockClient((request) async {
          throw http.ClientException(
            'Device is offline',
          );
        }),
      );

      await tester.pumpWidget(
        appFor(
          apiClient,
          offlineReadService:
              OfflineReadService(
            cache: cache,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Offline copy'),
        findsOneWidget,
      );

      expect(
        find.textContaining(
          'most recent encrypted copy',
        ),
        findsOneWidget,
      );

      expect(
        find.text('2025-08-12'),
        findsOneWidget,
      );

      expect(
        find.textContaining(
          'Changing your sobriety date',
        ),
        findsOneWidget,
      );

      final changeButton =
          tester.widget<FilledButton>(
        find.byKey(
          const ValueKey(
            'profile-change-sobriety-date',
          ),
        ),
      );

      expect(
        changeButton.onPressed,
        isNull,
      );

      apiClient.close();
    },
  );

  testWidgets(
    'Profile never exposes cached data after auth failure',
    (tester) async {
      final cache =
          MemoryOfflineCacheStore();

      await cache.write(
        'profile',
        OfflineCacheEntry(
          data: {
            'profile': {
              'sobriety_date':
                  '2020-01-01',
            },
          },
          cachedAt: DateTime.utc(
            2026,
            8,
            26,
          ),
        ),
      );

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient:
            MockClient((request) async {
          return http.Response(
            jsonEncode({}),
            401,
          );
        }),
      );

      await tester.pumpWidget(
        appFor(
          apiClient,
          offlineReadService:
              OfflineReadService(
            cache: cache,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(
          'Unable to load profile',
        ),
        findsOneWidget,
      );

      expect(
        find.text('Offline copy'),
        findsNothing,
      );

      expect(
        find.text('2020-01-01'),
        findsNothing,
      );

      expect(
        find.byKey(
          const ValueKey(
            'profile-sobriety-card',
          ),
        ),
        findsNothing,
      );

      apiClient.close();
    },
  );
}
