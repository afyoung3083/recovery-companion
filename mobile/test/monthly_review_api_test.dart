import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test('getCurrentMonthlyReview sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$baseUrl/monthly-review/current',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'review': 'Monthly Recovery Review',
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
        await apiClient.getCurrentMonthlyReview();

    expect(
      response['review'],
      'Monthly Recovery Review',
    );

    apiClient.close();
  });

  test('saveMonthlyReviewSnapshot sends authenticated POST', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        '$baseUrl/monthly-review/snapshot',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'snapshot': {
            'snapshot_date': '2026-08-23',
            'period_start': '2026-07-27',
            'period_end': '2026-08-23',
            'weekly_reviews_included': 4,
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
        await apiClient.saveMonthlyReviewSnapshot();

    expect(
      response['snapshot']['snapshot_date'],
      '2026-08-23',
    );

    apiClient.close();
  });

  test('getMonthlyReviewHistory sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$baseUrl/monthly-review/history',
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
              'snapshot_date': '2026-07-23',
            },
            {
              'snapshot_date': '2026-08-23',
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
        await apiClient.getMonthlyReviewHistory();

    expect(
      response['count'],
      2,
    );

    apiClient.close();
  });

  test('getMonthlyReviewComparison sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$baseUrl/monthly-review/comparison',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'comparison': 'Monthly Review Comparison',
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
        await apiClient.getMonthlyReviewComparison();

    expect(
      response['comparison'],
      'Monthly Review Comparison',
    );

    apiClient.close();
  });
}