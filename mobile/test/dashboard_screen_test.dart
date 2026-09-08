import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/dashboard_screen.dart';
import 'package:mobile/daily_checkin_screen.dart';
import 'package:mobile/journal_screen.dart';
import 'package:mobile/local_dashboard_repository.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/offline_read_service.dart';
import 'package:mobile/profile_screen.dart';
import 'package:mobile/secure_offline_cache_store.dart';
import 'package:mobile/step_work_screen.dart';

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<Map<String, String>> readAll() async => {};

  @override
  Future<void> write({required String key, required String value}) async {}
}

class FakeLocalDashboardRepository extends LocalDashboardRepository {
  FakeLocalDashboardRepository(this._data)
    : super(
        store: LocalRecoveryStore(
          dataFile: File('unused-dashboard-widget-test.enc'),
          keyStore: MemorySecureKeyValueStore(),
        ),
      );

  final Map<String, dynamic> _data;

  @override
  Future<Map<String, dynamic>> getDashboard() async => _data;
}

Map<String, dynamic> fakeLocalDashboardData() {
  return {
    'dashboard_data': {
      'sobriety_date': '2025-01-01',
      'sobriety_days': 42,
      'today_checkin': {'saved': false, 'completed_count': 0, 'total': 6},
      'current_step': 1,
      'open_assignments': <Map<String, dynamic>>[],
      'recommended_contacts': <Map<String, dynamic>>[],
    },
  };
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  Map<String, dynamic> dashboardResponse() {
    return <String, dynamic>{
      'dashboard': 'Legacy Dashboard text',
      'dashboard_data': <String, dynamic>{
        'sobriety_date': '2025-08-12',
        'sobriety_days': 378,
        'today_checkin': <String, dynamic>{
          'saved': true,
          'completed_count': 4,
          'total': 6,
          'note': 'Stayed connected today.',
        },
        'current_step': 8,
        'open_assignments': <Map<String, dynamic>>[
          <String, dynamic>{'id': 7, 'text': 'Review inventory.'},
        ],
        'latest_journal_entry': <String, dynamic>{
          'id': 9,
          'created_at': '2026-08-23T18:53:23',
          'text': 'Recovery reflection.',
        },
        'recommended_contacts': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 2,
            'handle': 'SponsorBob',
            'contact_type': 'sponsor',
            'contact_method': '555-0100',
            'notes': 'Call when isolating.',
            'active': true,
          },
          <String, dynamic>{
            'id': 3,
            'handle': 'RecoveryPeer',
            'contact_type': 'recovery_peer',
          },
        ],
        'generated_at': '2026-08-23T21:30:00',
      },
    };
  }

  Widget appFor(ApiClient apiClient, {OfflineReadService? offlineReadService}) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: DashboardScreen(
          apiClient: apiClient,
          offlineReadService: offlineReadService,
        ),
      ),
    );
  }

  testWidgets('Dashboard renders structured recovery cards', (tester) async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');

      expect(request.url.path, '/dashboard');

      expect(request.headers['Authorization'], 'Bearer $token');

      return http.Response(jsonEncode(dashboardResponse()), 200);
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(appFor(apiClient));

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-sobriety-card')),
      findsOneWidget,
    );

    expect(find.text('378 days'), findsOneWidget);

    expect(find.text('4 of 6'), findsOneWidget);

    expect(find.text('Step 8'), findsOneWidget);

    expect(find.text('Review inventory.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dashboard-latest-journal')),
      250,
    );

    expect(find.text('Recovery reflection.'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('SponsorBob'), 250);

    expect(find.text('SponsorBob'), findsOneWidget);

    expect(find.text('Legacy Dashboard text'), findsNothing);

    apiClient.close();
  });

  testWidgets('Dashboard handles empty recovery sections', (tester) async {
    final response = dashboardResponse();

    final data = response['dashboard_data'] as Map<String, dynamic>;

    data['open_assignments'] = <Map<String, dynamic>>[];

    data.remove('latest_journal_entry');

    data['recommended_contacts'] = <Map<String, dynamic>>[];

    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode(response), 200);
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(appFor(apiClient));

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('No open assignments').last, 250);

    expect(find.text('No open assignments'), findsNWidgets(2));

    await tester.scrollUntilVisible(find.text('No journal entries yet'), 250);

    expect(find.text('No journal entries yet'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('No contacts available'), 250);

    expect(find.text('No contacts available'), findsOneWidget);

    apiClient.close();
  });

  testWidgets('Dashboard retry reloads after API failure', (tester) async {
    var requestCount = 0;

    final mockClient = MockClient((request) async {
      requestCount += 1;

      if (requestCount == 1) {
        return http.Response('{}', 500);
      }

      return http.Response(jsonEncode(dashboardResponse()), 200);
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(appFor(apiClient));

    await tester.pumpAndSettle();

    expect(find.text('Unable to load Dashboard'), findsOneWidget);

    await tester.tap(find.text('Retry'));

    await tester.pumpAndSettle();

    expect(requestCount, 2);

    expect(find.text('378 days'), findsOneWidget);

    apiClient.close();
  });

  testWidgets(
    'Dashboard shows a loading state while local initialization is pending',
    (tester) async {
      var networkCalls = 0;

      final mockClient = MockClient((request) async {
        networkCalls += 1;
        throw StateError('Unexpected network request: ${request.url}');
      });

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DashboardScreen(
              apiClient: apiClient,
              localInitializationPending: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const ValueKey('dashboard-startup-loading')),
        findsOneWidget,
      );
      expect(find.text('Unable to load Dashboard'), findsNothing);
      expect(networkCalls, 0);
    },
  );

  testWidgets(
    'Dashboard automatically loads local data once initialization completes',
    (tester) async {
      var networkCalls = 0;

      final mockClient = MockClient((request) async {
        networkCalls += 1;
        throw StateError('Unexpected network request: ${request.url}');
      });

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DashboardScreen(
              apiClient: apiClient,
              localInitializationPending: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const ValueKey('dashboard-startup-loading')),
        findsOneWidget,
      );

      final repository = FakeLocalDashboardRepository(fakeLocalDashboardData());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DashboardScreen(
              apiClient: apiClient,
              localRepository: repository,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Unable to load Dashboard'), findsNothing);
      expect(
        find.byKey(const ValueKey('dashboard-sobriety-card')),
        findsOneWidget,
      );
      expect(networkCalls, 0);
    },
  );

  testWidgets(
    'Dashboard falls back and can still show Retry when init completes without a local repository',
    (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('{}', 500);
      });

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: DashboardScreen(apiClient: apiClient)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load Dashboard'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'Repository transition after a failed fallback reloads instead of leaving a stale error',
    (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('{}', 500);
      });

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: DashboardScreen(apiClient: apiClient)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load Dashboard'), findsOneWidget);

      final repository = FakeLocalDashboardRepository(fakeLocalDashboardData());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DashboardScreen(
              apiClient: apiClient,
              localRepository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load Dashboard'), findsNothing);
      expect(
        find.byKey(const ValueKey('dashboard-sobriety-card')),
        findsOneWidget,
      );
    },
  );
  testWidgets('Dashboard fellowship contact opens editable profile', (
    tester,
  ) async {
    final mockClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/dashboard') {
        return http.Response(jsonEncode(dashboardResponse()), 200);
      }

      throw StateError(
        'Unexpected request: '
        '${request.method} ${request.url}',
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(appFor(apiClient));

    await tester.pumpAndSettle();

    final contactTile = find.byKey(const ValueKey('dashboard-contact-2'));

    await tester.scrollUntilVisible(contactTile, 250);

    await tester.tap(contactTile);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('contact-profile-screen')),
      findsOneWidget,
    );

    expect(find.text('555-0100'), findsOneWidget);

    apiClient.close();
  });
  testWidgets('Dashboard recovery cards open their destination screens', (
    tester,
  ) async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/dashboard') {
        return http.Response(jsonEncode(dashboardResponse()), 200);
      }

      // Destination screens may load their own data.
      // Empty authenticated responses are sufficient for
      // this navigation-focused test.
      return http.Response(jsonEncode({}), 200);
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(appFor(apiClient));

    await tester.pumpAndSettle();

    await tester.tap(find.text('378 days'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('4 of 6'));
    await tester.pumpAndSettle();

    expect(find.byType(DailyCheckInScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Step 8'));
    await tester.pumpAndSettle();

    expect(find.byType(StepWorkScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final journalCard = find.byKey(const ValueKey('dashboard-journal-card'));

    await tester.scrollUntilVisible(journalCard, 250);

    await tester.tap(journalCard);
    await tester.pumpAndSettle();

    expect(find.byType(JournalScreen), findsOneWidget);

    apiClient.close();
  });
  testWidgets('Dashboard shows encrypted offline copy and recovers on retry', (
    tester,
  ) async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      OfflineCacheKeys.dashboard,
      OfflineCacheEntry(
        data: dashboardResponse(),
        cachedAt: DateTime.utc(2026, 8, 25, 20, 15),
      ),
    );

    var online = false;

    final mockClient = MockClient((request) async {
      if (!online) {
        throw http.ClientException('Device is offline');
      }

      return http.Response(jsonEncode(dashboardResponse()), 200);
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final offlineReadService = OfflineReadService(cache: cache);

    await tester.pumpWidget(
      appFor(apiClient, offlineReadService: offlineReadService),
    );

    await tester.pumpAndSettle();

    expect(find.text('Offline copy'), findsOneWidget);

    expect(find.textContaining('most recent encrypted copy'), findsOneWidget);

    expect(find.text('378 days'), findsOneWidget);

    online = true;

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Offline copy'), findsNothing);

    expect(find.text('378 days'), findsOneWidget);

    apiClient.close();
  });

  testWidgets('Dashboard never exposes cached data after auth failure', (
    tester,
  ) async {
    final cache = MemoryOfflineCacheStore();

    await cache.write(
      OfflineCacheKeys.dashboard,
      OfflineCacheEntry(
        data: dashboardResponse(),
        cachedAt: DateTime.utc(2026, 8, 25),
      ),
    );

    final mockClient = MockClient((request) async {
      return http.Response('{}', 401);
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      appFor(apiClient, offlineReadService: OfflineReadService(cache: cache)),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unable to load Dashboard'), findsOneWidget);

    expect(find.text('Offline copy'), findsNothing);

    expect(find.text('378 days'), findsNothing);

    apiClient.close();
  });
}
