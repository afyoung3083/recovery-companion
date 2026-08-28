import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/local_journal_repository.dart';
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
  test('local Journal AI retrieves only explicitly selected entry', () async {
    final directory = await Directory.systemTemp.createTemp(
      'journal_local_ai_test_',
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

    final repository = LocalJournalRepository(
      store: store,
      now: () => DateTime.utc(2026, 8, 27),
    );

    final first = await repository.createEntry(
      text: 'FIRST PRIVATE ENTRY',
      tags: ['first'],
    );

    await repository.createEntry(
      text: 'SECOND PRIVATE ENTRY',
      tags: ['second'],
    );

    final entry = first['entry'] as Map;

    final selected = await repository.getEntryForAiReflection(
      entry['id'] as int,
    );

    expect(selected['text'], 'FIRST PRIVATE ENTRY');

    expect(selected.toString(), isNot(contains('SECOND PRIVATE ENTRY')));
  });

  test('ApiClient sends selected local journal text', () async {
    const baseUrl = 'http://example.test';

    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');

      expect(request.url.toString(), '$baseUrl/journal/37/ai-reflection');

      expect(request.headers['Content-Type'], contains('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['text'], 'THIS EXACT LOCAL ENTRY');

      return http.Response(
        jsonEncode({'entry_id': 37, 'reflection': 'Journal reflection.'}),
        200,
      );
    });

    final client = ApiClient(
      baseUrl: baseUrl,
      apiToken: 'token',
      httpClient: mockClient,
    );

    final result = await client.analyzeJournalEntry(
      37,
      entryText: 'THIS EXACT LOCAL ENTRY',
    );

    expect(result['reflection'], 'Journal reflection.');

    client.close();
  });

  test('legacy Journal AI request still omits body', () async {
    const baseUrl = 'http://example.test';

    final mockClient = MockClient((request) async {
      expect(request.body, isEmpty);

      return http.Response(
        jsonEncode({'entry_id': 4, 'reflection': 'Legacy reflection.'}),
        200,
      );
    });

    final client = ApiClient(
      baseUrl: baseUrl,
      apiToken: 'token',
      httpClient: mockClient,
    );

    final result = await client.analyzeJournalEntry(4);

    expect(result['reflection'], 'Legacy reflection.');

    client.close();
  });
}
