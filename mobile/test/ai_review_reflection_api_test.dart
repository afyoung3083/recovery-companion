import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test('getWeeklyReviewAiReflection sends authenticated POST', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        '$baseUrl/weekly-review/ai-reflection',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'review': 'Weekly Recovery Review',
          'reflection': 'Observed strengths',
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final response =
        await apiClient.getWeeklyReviewAiReflection();

    expect(
      response['reflection'],
      'Observed strengths',
    );

    apiClient.close();
  });

  test('getMonthlyReviewAiReflection sends authenticated POST', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        '$baseUrl/monthly-review/ai-reflection',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'review': 'Monthly Recovery Review',
          'reflection': 'Observed strengths',
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final response =
        await apiClient.getMonthlyReviewAiReflection();

    expect(
      response['reflection'],
      'Observed strengths',
    );

    apiClient.close();
  });
}