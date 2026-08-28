import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/local_monthly_review_repository.dart';
import 'package:mobile/local_recovery_store.dart';
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
  test('local Monthly Review builds deterministic AI summary', () async {
    final directory = await Directory.systemTemp.createTemp(
      'monthly_ai_payload_test_',
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
      'weekly_reviews': [
        {
          'week_start': '2026-08-01',
          'week_end': '2026-08-07',
          'checkin_days': 4,
          'journal_entries': 2,
        },
        {
          'week_start': '2026-08-08',
          'week_end': '2026-08-14',
          'checkin_days': 5,
          'journal_entries': 3,
        },
      ],
      'journal_entries': [
        {'id': 1, 'text': 'PRIVATE JOURNAL TEXT'},
      ],
    });

    final repository = LocalMonthlyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    final payload = await repository.buildAiReflectionPayload();

    final summary = payload['summary'].toString();

    expect(summary, contains('Most recent 2 saved weeks'));

    expect(summary, contains('9 check-in days'));

    expect(summary, contains('5 journal entries'));

    expect(summary, isNot(contains('PRIVATE JOURNAL TEXT')));
  });

  test('ApiClient sends explicit local Monthly Review summary', () async {
    const baseUrl = 'http://example.test';

    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');

      expect(request.url.toString(), '$baseUrl/monthly-review/ai-reflection');

      expect(request.headers['Content-Type'], contains('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['summary'], 'LOCAL MONTHLY REVIEW');

      return http.Response(
        jsonEncode({
          'review': 'LOCAL MONTHLY REVIEW',
          'reflection': 'Monthly reflection.',
        }),
        200,
      );
    });

    final client = ApiClient(
      baseUrl: baseUrl,
      apiToken: 'token',
      httpClient: mockClient,
    );

    final result = await client.getMonthlyReviewAiReflection(
      summary: 'LOCAL MONTHLY REVIEW',
    );

    expect(result['reflection'], 'Monthly reflection.');

    client.close();
  });

  test('legacy Monthly Review AI request still omits body', () async {
    const baseUrl = 'http://example.test';

    final mockClient = MockClient((request) async {
      expect(request.body, isEmpty);

      return http.Response(
        jsonEncode({
          'review': 'Server monthly review',
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

    final result = await client.getMonthlyReviewAiReflection();

    expect(result['reflection'], 'Legacy reflection.');

    client.close();
  });
}
