import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';

void main() {
  const token = 'test-token';

  test('getStepWork sends bearer token', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'http://example.test/step-work',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'step_work': {
            'current_step': 4,
            'assignments': [],
            'notes': [],
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

    final result = await apiClient.getStepWork();

    expect(
      result['step_work']['current_step'],
      4,
    );
  });

  test('setCurrentStep sends authenticated JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        'http://example.test/step-work/current-step',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      final body =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(
        body['step_number'],
        5,
      );

      return http.Response(
        jsonEncode({
          'step_work': {
            'current_step': 5,
            'assignments': [],
            'notes': [],
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

    final result = await apiClient.setCurrentStep(5);

    expect(
      result['step_work']['current_step'],
      5,
    );
  });

  test('createStepAssignment sends authenticated JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'http://example.test/step-work/assignments',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      final body =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(
        body['text'],
        'Write resentment inventory.',
      );

      return http.Response(
        jsonEncode({
          'assignment': {
            'id': 1,
            'step': 4,
            'text': body['text'],
            'completed': false,
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

    final result = await apiClient.createStepAssignment(
      'Write resentment inventory.',
    );

    expect(
      result['assignment']['completed'],
      false,
    );
  });

  test('completeStepAssignment sends authenticated request', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        'http://example.test/step-work/assignments/3/complete',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'assignment': {
            'id': 3,
            'step': 4,
            'text': 'Call sponsor.',
            'completed': true,
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

    final result =
        await apiClient.completeStepAssignment(3);

    expect(
      result['assignment']['completed'],
      true,
    );
  });
}