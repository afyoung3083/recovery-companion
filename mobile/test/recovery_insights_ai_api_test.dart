import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test(
    'getRecoveryInsightsAiReflection sends authenticated empty POST',
    () async {
      final mockClient = MockClient((request) async {
        expect(
          request.method,
          'POST',
        );

        expect(
          request.url.toString(),
          '$baseUrl/recovery-insights/ai-reflection',
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
            'reflection':
                'Human connection may be worth continuing to prioritize.',
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
          await apiClient.getRecoveryInsightsAiReflection();

      expect(
        result['reflection'],
        'Human connection may be worth continuing to prioritize.',
      );

      apiClient.close();
    },
  );

  test(
    'getRecoveryInsightsAiReflection surfaces API failure',
    () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail':
                'Unable to generate Recovery Insights reflection.',
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
        () => apiClient.getRecoveryInsightsAiReflection(),
        throwsA(isA<ApiException>()),
      );

      apiClient.close();
    },
  );
}
