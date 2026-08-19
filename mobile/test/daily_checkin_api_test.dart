import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';

void main() {
  const token = 'test-token';

  test('getTodayCheckin sends bearer token', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.method,
        'GET',
      );

      expect(
        request.url.toString(),
        'http://example.test/daily-checkin/today',
      );

      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'date': '2026-08-19',
          'checkin': {
            'meeting': true,
            'journal': false,
          },
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.getTodayCheckin();

    expect(
      result['date'],
      '2026-08-19',
    );

    expect(
      result['checkin']['meeting'],
      true,
    );
  });

  test('saveTodayCheckin sends authenticated JSON', () async {
    final mockClient = MockClient((request) async {
      expect(
        request.method,
        'PUT',
      );

      expect(
        request.url.toString(),
        'http://example.test/daily-checkin/today',
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
        body['prayer_meditation'],
        true,
      );

      expect(
        body['recovery_contact'],
        true,
      );

      expect(
        body['meeting'],
        false,
      );

      expect(
        body['step_work'],
        true,
      );

      expect(
        body['journal'],
        true,
      );

      expect(
        body['service'],
        false,
      );

      expect(
        body['note'],
        'Stayed connected.',
      );

      return http.Response(
        jsonEncode({
          'checkin': {
            'date': '2026-08-19',
            ...body,
          },
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: token,
      httpClient: mockClient,
    );

    final result = await apiClient.saveTodayCheckin(
      prayerMeditation: true,
      recoveryContact: true,
      meeting: false,
      stepWork: true,
      journal: true,
      service: false,
      note: 'Stayed connected.',
    );

    expect(
      result['checkin']['recovery_contact'],
      true,
    );

    expect(
      result['checkin']['note'],
      'Stayed connected.',
    );
  });
}