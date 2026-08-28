import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/local_insights_repository.dart';
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
  test('local Insights AI payload contains aggregate recovery data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'insights_ai_payload_test_',
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
      'profile': {'sobriety_date': '2026-08-12'},
      'step_work': {
        'current_step': 4,
        'assignments': [
          {'id': 1, 'step': 4, 'completed': false},
        ],
      },
      'goals': [
        {'id': 1, 'active': true},
      ],
      'daily_checkins': {'2026-08-27': {}, '2026-08-26': {}},
    });

    final repository = LocalInsightsRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    final payload = await repository.buildAiReflectionPayload();

    final summary = payload['summary'].toString();

    expect(summary, contains('Sobriety: 15 days'));

    expect(summary, contains('Current Step: 4'));

    expect(summary, contains('Open Step assignments: 1'));

    expect(summary, contains('Active recovery goals: 1'));

    expect(summary, contains('Recent check-in days: 2 of 7'));
  });

  test(
    'local Insights AI payload excludes raw journal and check-in notes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'insights_ai_privacy_test_',
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
        'journal_entries': [
          {'id': 1, 'text': 'DO NOT SEND THIS JOURNAL'},
        ],
        'daily_checkins': {
          '2026-08-27': {'note': 'DO NOT SEND THIS NOTE'},
        },
      });

      final repository = LocalInsightsRepository(
        store: store,
        now: () => DateTime(2026, 8, 27, 12),
      );

      final payload = await repository.buildAiReflectionPayload();

      final summary = payload['summary'].toString();

      expect(summary, isNot(contains('DO NOT SEND THIS JOURNAL')));

      expect(summary, isNot(contains('DO NOT SEND THIS NOTE')));
    },
  );

  test('ApiClient sends explicit local Insights summary', () async {
    const baseUrl = 'http://example.test';

    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');

      expect(
        request.url.toString(),
        '$baseUrl/recovery-insights/ai-reflection',
      );

      expect(request.headers['Content-Type'], contains('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['summary'], 'LOCAL INSIGHTS SUMMARY');

      return http.Response(
        jsonEncode({'reflection': 'Local insights reflection.'}),
        200,
      );
    });

    final client = ApiClient(
      baseUrl: baseUrl,
      apiToken: 'token',
      httpClient: mockClient,
    );

    final result = await client.getRecoveryInsightsAiReflection(
      summary: 'LOCAL INSIGHTS SUMMARY',
    );

    expect(result['reflection'], 'Local insights reflection.');

    client.close();
  });
}
