import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';


void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test('exportRecoveryData sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        '$baseUrl/data-ownership/export',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'export': {
            'metadata': {
              'backup_format_version': 1,
              'sha256': 'example-hash',
            },
            'profile': {
              'sobriety_date': '2025-08-12',
            },
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
        await apiClient.exportRecoveryData();

    expect(
      response['export']['metadata']
          ['backup_format_version'],
      1,
    );
    expect(
      response['export']['profile']
          ['sobriety_date'],
      '2025-08-12',
    );

    apiClient.close();
  });

  test('deleteRecoveryData sends confirmation JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(
        request.url.toString(),
        '$baseUrl/data-ownership',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );
      expect(
        request.headers['Content-Type'],
        contains('application/json'),
      );

      final body =
          jsonDecode(request.body)
              as Map<String, dynamic>;

      expect(
        body['confirmation'],
        'DELETE MY RECOVERY DATA',
      );

      return http.Response(
        jsonEncode({
          'deleted': true,
          'deleted_data_files': 9,
          'deleted_backup_files': 2,
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
        await apiClient.deleteRecoveryData(
      confirmation: 'DELETE MY RECOVERY DATA',
    );

    expect(response['deleted'], true);
    expect(response['deleted_data_files'], 9);
    expect(response['deleted_backup_files'], 2);

    apiClient.close();
  });
}
