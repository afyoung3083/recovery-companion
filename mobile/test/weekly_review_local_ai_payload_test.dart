import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/local_weekly_review_repository.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(values);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

void main() {
  test('local Weekly Review builds deterministic AI summary', () async {
    final directory = await Directory.systemTemp.createTemp(
      'weekly_ai_payload_test_',
    );

    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}'
        '${Platform.pathSeparator}'
        'recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    await store.write({
      'daily_checkins': {'2026-08-27': {}, '2026-08-26': {}},
      'journal_entries': [
        {'id': 1, 'date': '2026-08-27', 'text': 'PRIVATE JOURNAL TEXT'},
      ],
      'goals': [
        {'id': 1, 'active': true},
      ],
      'routines': [
        {'id': 1, 'active': true},
      ],
    });

    final repository = LocalWeeklyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    final payload = await repository.buildAiReflectionPayload();

    final summary = payload['summary'].toString();

    expect(summary, contains('2 check-in days'));
    expect(summary, contains('1 journal entries'));
    expect(summary, contains('1 active goals'));
    expect(summary, contains('1 active routines'));

    expect(summary, isNot(contains('PRIVATE JOURNAL TEXT')));
  });

  test('ApiClient sends explicit local Weekly Review summary', () async {
    const baseUrl = 'http://example.test';

    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');

      expect(request.url.toString(), '$baseUrl/weekly-review/ai-reflection');

      expect(request.headers['Content-Type'], contains('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['summary'], 'LOCAL WEEKLY REVIEW');

      return http.Response(
        jsonEncode({
          'review': 'LOCAL WEEKLY REVIEW',
          'reflection': 'Weekly reflection.',
        }),
        200,
      );
    });

    final client = ApiClient(
      baseUrl: baseUrl,
      apiToken: 'token',
      httpClient: mockClient,
    );

    final result = await client.getWeeklyReviewAiReflection(
      summary: 'LOCAL WEEKLY REVIEW',
    );

    expect(result['reflection'], 'Weekly reflection.');

    client.close();
  });

  test('legacy Weekly Review AI request still omits body', () async {
    const baseUrl = 'http://example.test';

    final mockClient = MockClient((request) async {
      expect(request.body, isEmpty);

      return http.Response(
        jsonEncode({
          'review': 'Server review',
          'reflection': 'Legacy reflection.',
        }),
        200,
      );
    });

    final client = ApiClient(
      baseUrl: baseUrl,
      apiToken: 'token',
      httpClient: mockClient,
    );

    final result = await client.getWeeklyReviewAiReflection();

    expect(result['reflection'], 'Legacy reflection.');

    client.close();
  });
}
