import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';

void main() {
  const token = 'test-token';

  test('getGoals sends bearer token', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      expect(
        request.url.toString(),
        'http://example.test/goals',
      );

      return http.Response(
        '{"count":0,"goals":[]}',
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.getGoals();

    expect(result['count'], 0);
  });

  test('getRoutines sends bearer token', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      expect(
        request.url.toString(),
        'http://example.test/routines',
      );

      return http.Response(
        '{"count":1,"routines":[{"id":1}]}',
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.getRoutines();

    expect(result['count'], 1);
  });

  test('getRecoveryInsights sends bearer token', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      expect(
        request.url.toString(),
        'http://example.test/recovery-insights',
      );

      return http.Response(
        '{"recovery_insights":"Test insights"}',
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.getRecoveryInsights();

    expect(
      result['recovery_insights'],
      'Test insights',
    );
  });
}