import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test('analyzeJournalEntry sends selected entry ID', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');

      expect(
        request.url.toString(),
        '$baseUrl/journal/7/ai-reflection',
      );

      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      expect(request.body, isEmpty);

      return http.Response(
        jsonEncode({
          'entry_id': 7,
          'reflection':
              'You described choosing connection instead of isolation.',
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.analyzeJournalEntry(7);

    expect(result['entry_id'], 7);
    expect(
      result['reflection'],
      'You described choosing connection instead of isolation.',
    );

    apiClient.close();
  });

  test('analyzeJournalEntry surfaces API failure', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'detail': 'Unable to generate journal reflection.',
        }),
        502,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    expect(
      () => apiClient.analyzeJournalEntry(7),
      throwsA(isA<ApiException>()),
    );

    apiClient.close();
  });
}
