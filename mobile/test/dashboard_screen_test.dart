import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/dashboard_screen.dart';

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

  Widget appFor(ApiClient apiClient) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: DashboardScreen(apiClient: apiClient)),
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
}
