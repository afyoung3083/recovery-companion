import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';

void main() {
  const token = 'test-token';

  test('getJournalEntries sends bearer token', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.method,
        'GET',
      );

      expect(
        request.url.toString(),
        'http://example.test/journal',
      );

      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'count': 1,
          'entries': [
            {
              'id': 1,
              'text': 'Stayed connected today.',
              'tags': ['connection'],
            }
          ],
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.getJournalEntries();

    expect(
      result['count'],
      1,
    );
  });

  test('createJournalEntry sends authenticated JSON', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.method,
        'POST',
      );

      expect(
        request.url.toString(),
        'http://example.test/journal',
      );

      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      expect(
        request.headers['Content-Type'],
        contains('application/json'),
      );

      final body = jsonDecode(
        request.body,
      ) as Map<String, dynamic>;

      expect(
        body['text'],
        'Called my sponsor.',
      );

      expect(
        body['tags'],
        [
          'connection',
          'sponsor',
        ],
      );

      return http.Response(
        jsonEncode({
          'entry': {
            'id': 2,
            'text': body['text'],
            'tags': body['tags'],
          },
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.createJournalEntry(
      text: 'Called my sponsor.',
      tags: [
        'connection',
        'sponsor',
      ],
    );

    expect(
      result['entry']['id'],
      2,
    );
  });

  test('searchJournal sends encoded query and bearer token', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.method,
        'GET',
      );

      expect(
        request.url.path,
        '/journal/search',
      );

      expect(
        request.url.queryParameters['q'],
        'sponsor meeting',
      );

      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'count': 1,
          'entries': [
            {
              'id': 1,
              'text': 'Sponsor meeting tonight.',
              'tags': ['sponsor'],
            }
          ],
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.searchJournal(
      'sponsor meeting',
    );

    expect(
      result['count'],
      1,
    );
  });
}