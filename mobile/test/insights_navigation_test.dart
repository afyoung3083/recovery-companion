import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/insights_screen.dart';

class _NavigationCase {
  const _NavigationCase({required this.keyName, required this.destination});

  final String keyName;
  final InsightsDestination destination;
}

Map<String, dynamic> insightsResponse() {
  return {
    'recovery_insights_data': {
      'sobriety_days': 100,
      'sobriety_date': '2026-05-24',
      'current_step': 8,
      'open_step_assignments': 2,
      'active_recovery_goals': 3,
      'checkin_days_available': 6,
      'checkin_window_days': 7,
      'latest_weekly_snapshot': {
        'week_start': '2026-08-24',
        'week_end': '2026-08-30',
        'checkin_days': 6,
        'journal_entries': 4,
      },
      'latest_monthly_snapshot': {
        'period_start': '2026-08-01',
        'period_end': '2026-08-31',
        'weekly_reviews_included': 4,
        'checkin_days': 25,
        'journal_entries': 14,
      },
    },
  };
}

Future<void> revealCard(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  const cases = [
    _NavigationCase(
      keyName: 'recovery-insights-sobriety-card',
      destination: InsightsDestination.profile,
    ),
    _NavigationCase(
      keyName: 'recovery-insights-step-work-card',
      destination: InsightsDestination.stepWork,
    ),
    _NavigationCase(
      keyName: 'recovery-insights-checkins-card',
      destination: InsightsDestination.dailyRecovery,
    ),
    _NavigationCase(
      keyName: 'recovery-insights-goals-card',
      destination: InsightsDestination.goals,
    ),
    _NavigationCase(
      keyName: 'recovery-insights-weekly-card',
      destination: InsightsDestination.weeklyReview,
    ),
    _NavigationCase(
      keyName: 'recovery-insights-monthly-card',
      destination: InsightsDestination.monthlyReview,
    ),
  ];

  for (final navigationCase in cases) {
    testWidgets('${navigationCase.keyName} opens '
        '${navigationCase.destination.name}', (tester) async {
      InsightsDestination? opened;

      final mockClient = MockClient((request) async {
        if (request.method != 'GET' ||
            request.url.path != '/recovery-insights') {
          throw StateError(
            'Unexpected request: '
            '${request.method} '
            '${request.url}',
          );
        }

        return http.Response(jsonEncode(insightsResponse()), 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://example.test',
        apiToken: 'test-token',
        httpClient: mockClient,
      );

      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InsightsScreen(
              apiClient: apiClient,
              onOpenDestination: (destination) async {
                opened = destination;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final card = find.byKey(ValueKey(navigationCase.keyName));

      await revealCard(tester, card);

      expect(card, findsOneWidget);

      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(opened, navigationCase.destination);
    });
  }

  test('HomeShell maps every Insights destination', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('onOpenDestination:'));

    const destinations = [
      'profile',
      'stepWork',
      'dailyRecovery',
      'goals',
      'weeklyReview',
      'monthlyReview',
    ];

    for (final destination in destinations) {
      expect(
        source,
        contains(
          'case InsightsDestination.'
          '$destination:',
        ),
      );
    }

    const screens = [
      'ProfileScreen(',
      'StepWorkScreen(',
      'DailyCheckInScreen(',
      'GoalsScreen(',
      'WeeklyReviewScreen(',
      'MonthlyReviewScreen(',
    ];

    for (final screen in screens) {
      expect(source, contains(screen));
    }
  });
}
