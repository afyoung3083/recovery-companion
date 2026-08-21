import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test('createGoal sends authenticated POST with expected JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), '$baseUrl/goals');
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      final body =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['text'], 'Attend three meetings');
      expect(body['area'], 'meetings');
      expect(body['target_date'], '2026-08-31');

      return http.Response(
        jsonEncode({
          'goal': {
            'id': 1,
            'text': 'Attend three meetings',
            'area': 'meetings',
            'target_date': '2026-08-31',
            'status': 'active',
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

    final response = await apiClient.createGoal(
      text: 'Attend three meetings',
      area: 'meetings',
      targetDate: '2026-08-31',
    );

    expect(response['goal']['status'], 'active');

    apiClient.close();
  });

  test('completeGoal sends authenticated PUT', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        '$baseUrl/goals/4/complete',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'goal': {
            'id': 4,
            'status': 'completed',
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

    final response = await apiClient.completeGoal(4);

    expect(response['goal']['status'], 'completed');

    apiClient.close();
  });

  test('reactivateGoal sends authenticated PUT', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        '$baseUrl/goals/4/reactivate',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'goal': {
            'id': 4,
            'status': 'active',
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

    final response = await apiClient.reactivateGoal(4);

    expect(response['goal']['status'], 'active');

    apiClient.close();
  });

  test('createRoutine sends authenticated POST with expected JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), '$baseUrl/routines');
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      final body =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['text'], 'Call sponsor');
      expect(body['area'], 'connection');
      expect(body['frequency'], 'weekly');
      expect(body['day_of_week'], 'friday');

      return http.Response(
        jsonEncode({
          'routine': {
            'id': 2,
            'text': 'Call sponsor',
            'area': 'connection',
            'frequency': 'weekly',
            'day_of_week': 'friday',
            'active': true,
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

    final response = await apiClient.createRoutine(
      text: 'Call sponsor',
      area: 'connection',
      frequency: 'weekly',
      dayOfWeek: 'friday',
    );

    expect(response['routine']['active'], true);

    apiClient.close();
  });

  test('setRoutineActive sends authenticated PUT with expected JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        '$baseUrl/routines/2/active',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      final body =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['active'], false);

      return http.Response(
        jsonEncode({
          'routine': {
            'id': 2,
            'active': false,
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

    final response = await apiClient.setRoutineActive(
      routineId: 2,
      active: false,
    );

    expect(response['routine']['active'], false);

    apiClient.close();
  });
}