import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/local_daily_checkin_repository.dart';
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
  test('local Daily Recovery builds at most seven recent check-ins', () async {
    final directory = await Directory.systemTemp.createTemp(
      'daily_ai_payload_test_',
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

    final checkins = <String, dynamic>{};

    for (var day = 1; day <= 9; day++) {
      final date = '2026-08-${day.toString().padLeft(2, '0')}';

      checkins[date] = {
        'date': date,
        'meeting': day.isEven,
        'recovery_contact': true,
        'note': 'Note $day',
      };
    }

    await store.write({'daily_checkins': checkins});

    final repository = LocalDailyCheckInRepository(store: store);

    final payload = await repository.buildAiReflectionPayload();

    expect(payload['checkin_count'], 7);

    final summary = payload['summary'].toString();

    expect(summary, contains('2026-08-09'));

    expect(summary, contains('2026-08-03'));

    expect(summary, isNot(contains('2026-08-02')));
  });

  test('local summary contains deterministic counts and notes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'daily_ai_summary_test_',
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
      'daily_checkins': {
        '2026-08-27': {
          'meeting': true,
          'recovery_contact': true,
          'note': 'Called sponsor.',
        },
      },
    });

    final repository = LocalDailyCheckInRepository(store: store);

    final payload = await repository.buildAiReflectionPayload();

    final summary = payload['summary'].toString();

    expect(summary, contains('2/6 completed'));

    expect(summary, contains('Note: Called sponsor.'));

    expect(summary, contains('Meeting: 1/1'));

    expect(summary, contains('Recovery contact: 1/1'));
  });

  test('ApiClient sends explicit local Daily Recovery summary', () async {
    const baseUrl = 'http://example.test';

    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');

      expect(request.url.toString(), '$baseUrl/daily-checkin/ai-reflection');

      expect(request.headers['Content-Type'], contains('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['summary'], 'LOCAL CHECK-IN SUMMARY');

      expect(body['checkin_count'], 3);

      return http.Response(
        jsonEncode({'checkin_count': 3, 'reflection': 'Reflection'}),
        200,
      );
    });

    final client = ApiClient(
      baseUrl: baseUrl,
      apiToken: 'token',
      httpClient: mockClient,
    );

    final result = await client.analyzeRecentCheckins(
      summary: 'LOCAL CHECK-IN SUMMARY',
      checkinCount: 3,
    );

    expect(result['reflection'], 'Reflection');

    client.close();
  });
}
