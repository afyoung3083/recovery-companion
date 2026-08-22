import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test('getCurrentWeeklyReview sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$baseUrl/weekly-review/current',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'review': 'Weekly Recovery Review',
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
        await apiClient.getCurrentWeeklyReview();

    expect(
      response['review'],
      'Weekly Recovery Review',
    );

    apiClient.close();
  });

  test('saveWeeklyReviewSnapshot sends authenticated POST', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        '$baseUrl/weekly-review/snapshot',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'snapshot': {
            'week_start': '2026-08-16',
            'week_end': '2026-08-22',
            'checkin_days': 5,
          },
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
        await apiClient.saveWeeklyReviewSnapshot();

    expect(
      response['snapshot']['week_end'],
      '2026-08-22',
    );

    apiClient.close();
  });

  test('getWeeklyReviewHistory sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$baseUrl/weekly-review/history',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'count': 2,
          'history': [
            {
              'week_start': '2026-08-09',
              'week_end': '2026-08-15',
            },
            {
              'week_start': '2026-08-16',
              'week_end': '2026-08-22',
            },
          ],
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
        await apiClient.getWeeklyReviewHistory();

    expect(
      response['count'],
      2,
    );

    apiClient.close();
  });

  test('getWeeklyReviewComparison sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$baseUrl/weekly-review/comparison',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'comparison': 'Weekly Review Comparison',
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
        await apiClient.getWeeklyReviewComparison();

    expect(
      response['comparison'],
      'Weekly Review Comparison',
    );

    apiClient.close();
  });
}