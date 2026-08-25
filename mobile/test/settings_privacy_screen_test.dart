import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/settings_privacy_screen.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('Settings & Privacy prepares recovery export', (tester) async {
    var exportCalled = false;

    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/data-ownership/export');
      expect(request.headers['Authorization'], 'Bearer $token');

      exportCalled = true;

      return http.Response(
        jsonEncode({
          'export': {
            'metadata': {
              'backup_format_version': 1,
              'created_at': '2026-08-25T08:15:00',
              'sha256': 'abc123',
            },
            'profile': {'sobriety_date': '2025-08-12'},
            'journal_entries': [],
            'step_work': {'current_step': 8, 'assignments': [], 'notes': []},
            'fellowship_contacts': [],
            'daily_checkins': [],
            'weekly_reviews': [],
            'monthly_reviews': [],
            'goals': [],
            'routines': [],
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
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: SettingsPrivacyScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Settings & Privacy'), findsOneWidget);
    expect(find.text('AI & privacy'), findsOneWidget);

    final exportButton = find.byKey(const ValueKey('prepare-data-export'));

    await tester.scrollUntilVisible(exportButton, 250);

    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(exportCalled, true);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Export ready'), findsOneWidget);
    expect(find.text('Created: 2026-08-25T08:15:00'), findsOneWidget);
    expect(find.byKey(const ValueKey('copy-data-export')), findsOneWidget);

    apiClient.close();
  });

  testWidgets('Deletion requires exact phrase and second confirmation', (
    tester,
  ) async {
    var deleteCalled = false;

    final mockClient = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleteCalled = true;

        return http.Response(
          jsonEncode({
            'deleted': true,
            'deleted_data_files': 9,
            'deleted_backup_files': 1,
          }),
          200,
        );
      }

      return http.Response('{}', 200);
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: SettingsPrivacyScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const ValueKey('delete-recovery-data'));

    await tester.scrollUntilVisible(deleteButton, 300);

    final buttonBefore = tester.widget<FilledButton>(deleteButton);

    expect(buttonBefore.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('delete-confirmation-field')),
      'DELETE MY RECOVERY DATA',
    );
    await tester.pump();

    final buttonAfter = tester.widget<FilledButton>(deleteButton);

    expect(buttonAfter.onPressed, isNotNull);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Permanently delete recovery data?'), findsOneWidget);

    expect(deleteCalled, false);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(deleteCalled, false);

    apiClient.close();
  });
}
