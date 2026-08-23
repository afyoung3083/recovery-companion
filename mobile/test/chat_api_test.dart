import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test(
    'sendChat sends authenticated ordered conversation',
    () async {
      final conversation = [
        {
          'role': 'user',
          'content': 'I had a difficult morning.',
        },
        {
          'role': 'assistant',
          'content': 'What felt most difficult?',
        },
        {
          'role': 'user',
          'content': 'I wanted to isolate.',
        },
      ];

      final mockClient = MockClient(
        (request) async {
          expect(
            request.method,
            'POST',
          );

          expect(
            request.url.toString(),
            '$baseUrl/chat',
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
            body['conversation'],
            conversation,
          );

          return http.Response(
            jsonEncode({
              'response':
                  'It sounds like isolation was pulling at you.',
            }),
            200,
          );
        },
      );

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );

      final response = await apiClient.sendChat(
        conversation: conversation,
      );

      expect(
        response['response'],
        'It sounds like isolation was pulling at you.',
      );

      apiClient.close();
    },
  );

  test(
    'sendChat throws ApiException on API failure',
    () async {
      final mockClient = MockClient(
        (request) async {
          return http.Response(
            jsonEncode({
              'detail':
                  'Unable to generate a Recovery Companion response.',
            }),
            502,
          );
        },
      );

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );

      expect(
        apiClient.sendChat(
          conversation: const [
            {
              'role': 'user',
              'content': 'Hello',
            },
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            502,
          ),
        ),
      );

      apiClient.close();
    },
  );
}
