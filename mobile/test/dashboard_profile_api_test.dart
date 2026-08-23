import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test('getDashboard sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$baseUrl/dashboard',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'dashboard':
              'Daily Recovery Dashboard\nSobriety: 12 day(s)',
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.getDashboard();

    expect(
      result['dashboard'],
      'Daily Recovery Dashboard\nSobriety: 12 day(s)',
    );

    apiClient.close();
  });

  test('getProfile sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$baseUrl/profile',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'profile': {
            'sobriety_date': '2026-08-12',
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

    final result = await apiClient.getProfile();

    final profile =
        result['profile'] as Map<String, dynamic>;

    expect(
      profile['sobriety_date'],
      '2026-08-12',
    );

    apiClient.close();
  });

  test('updateSobrietyDate sends authenticated JSON PUT', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        '$baseUrl/profile/sobriety-date',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );
      expect(
        request.headers['Content-Type'],
        startsWith('application/json'),
      );

      expect(
        jsonDecode(request.body),
        {
          'sobriety_date': '2026-08-12',
        },
      );

      return http.Response(
        jsonEncode({
          'profile': {
            'sobriety_date': '2026-08-12',
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

    final result = await apiClient.updateSobrietyDate(
      '2026-08-12',
    );

    final profile =
        result['profile'] as Map<String, dynamic>;

    expect(
      profile['sobriety_date'],
      '2026-08-12',
    );

    apiClient.close();
  });

  test('updateSobrietyDate surfaces API failure', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'detail':
              'Sobriety date cannot be in the future.',
        }),
        400,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    expect(
      () => apiClient.updateSobrietyDate(
        '2999-01-01',
      ),
      throwsA(isA<ApiException>()),
    );

    apiClient.close();
  });
}
