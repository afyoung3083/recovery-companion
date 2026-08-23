import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test('analyzeRecentCheckins sends authenticated empty POST', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.method,
        'POST',
      );

      expect(
        request.url.toString(),
        '$baseUrl/daily-checkin/ai-reflection',
      );

      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      expect(
        request.body,
        isEmpty,
      );

      return http.Response(
        jsonEncode({
          'checkin_count': 3,
          'reflection': 'Connection has been visible recently.',
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final result =
        await apiClient.analyzeRecentCheckins();

    expect(
      result['checkin_count'],
      3,
    );

    expect(
      result['reflection'],
      'Connection has been visible recently.',
    );

    apiClient.close();
  });

  test('analyzeRecentCheckins surfaces API failure', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'detail': 'Unable to generate check-in reflection.',
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
      () => apiClient.analyzeRecentCheckins(),
      throwsA(isA<ApiException>()),
    );

    apiClient.close();
  });
}
