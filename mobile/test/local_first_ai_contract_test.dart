import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) {
    return File(path).readAsStringSync();
  }

  test('all recovery AI client methods support explicit local payloads', () {
    final apiClient = source('lib/api_client.dart');

    expect(
      apiClient,
      contains('Future<Map<String, dynamic>> analyzeRecentCheckins({'),
    );

    expect(
      apiClient,
      contains(
        'Future<Map<String, dynamic>> getRecoveryInsightsAiReflection({',
      ),
    );

    expect(
      apiClient,
      contains('Future<Map<String, dynamic>> getWeeklyReviewAiReflection({'),
    );

    expect(
      apiClient,
      contains('Future<Map<String, dynamic>> getMonthlyReviewAiReflection({'),
    );

    expect(apiClient, contains('String? entryText'));
  });

  test('local-first recovery screens use their local AI payload builders', () {
    expect(
      source('lib/daily_checkin_screen.dart'),
      contains('buildAiReflectionPayload()'),
    );

    expect(
      source('lib/insights_screen.dart'),
      contains('buildAiReflectionPayload()'),
    );

    expect(
      source('lib/weekly_review_screen.dart'),
      contains('buildAiReflectionPayload()'),
    );

    expect(
      source('lib/monthly_review_screen.dart'),
      contains('buildAiReflectionPayload()'),
    );

    expect(
      source('lib/journal_screen.dart'),
      contains('getEntryForAiReflection('),
    );
  });

  test('local AI reflection is no longer blocked by stale server sync', () {
    const screens = [
      'lib/insights_screen.dart',
      'lib/weekly_review_screen.dart',
      'lib/monthly_review_screen.dart',
    ];

    for (final path in screens) {
      expect(
        source(path),
        isNot(contains('AI Reflection Requires Sync')),
        reason: path,
      );
    }
  });

  test('Journal sends selected local entry text rather than only local ID', () {
    final journalScreen = source('lib/journal_screen.dart');

    final apiClient = source('lib/api_client.dart');

    expect(journalScreen, contains('getEntryForAiReflection('));

    expect(journalScreen, contains('entryText: entryText'));

    expect(apiClient, contains("'text': entryText.trim()"));
  });

  test('Chat shares only the explicit session conversation', () {
    final chat = source('lib/chat_screen.dart');

    expect(chat, contains('conversation: _conversation'));

    expect(chat, isNot(contains('LocalRecoveryStore')));

    expect(chat, isNot(contains('getRecoveryInsights')));

    expect(chat, isNot(contains('getJournalEntries')));
  });
}
