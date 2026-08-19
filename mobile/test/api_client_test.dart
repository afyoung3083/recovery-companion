import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';

void main() {
  test('getHealth returns decoded health response', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.url.toString(),
        'http://example.test/health',
      );

      return http.Response(
        '{"status":"ok","version":"1.16.0"}',
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      httpClient: mockClient,
    );

    final result = await apiClient.getHealth();

    expect(result['status'], 'ok');
    expect(result['version'], '1.16.0');
  });

  test('getHealth throws ApiException on HTTP failure', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        '{"detail":"Server error"}',
        500,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      httpClient: mockClient,
    );

    expect(
      apiClient.getHealth(),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.statusCode,
              'statusCode',
              500,
            ),
      ),
    );
  });

  test('authenticatedHeaders includes bearer token', () {
    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
    );

    expect(
      apiClient.authenticatedHeaders,
      {
        'Authorization': 'Bearer test-token',
      },
    );

    apiClient.close();
  });

  test('authenticatedHeaders is empty without token', () {
    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
    );

    expect(
      apiClient.authenticatedHeaders,
      isEmpty,
    );

    apiClient.close();
  });
}