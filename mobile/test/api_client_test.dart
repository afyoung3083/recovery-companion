import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';

void main() {
  test('getHealth returns decoded health response', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.toString(), 'http://example.test/health');

      return http.Response('{"status":"ok","version":"1.16.0"}', 200);
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
      return http.Response('{"detail":"Server error"}', 500);
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      httpClient: mockClient,
    );

    expect(
      apiClient.getHealth(),
      throwsA(
        isA<ApiException>().having(
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

    expect(apiClient.authenticatedHeaders, {
      'Authorization': 'Bearer test-token',
    });

    apiClient.close();
  });

  test('authenticatedHeaders is empty without token', () {
    final apiClient = ApiClient(baseUrl: 'http://example.test');

    expect(apiClient.authenticatedHeaders, isEmpty);

    apiClient.close();
  });
  test('request timeout prevents indefinite network hangs', () async {
    final neverCompletes = Completer<http.Response>();

    final mockClient = MockClient((request) {
      return neverCompletes.future;
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: mockClient,
      requestTimeout: const Duration(milliseconds: 25),
    );

    addTearDown(apiClient.close);

    await expectLater(
      apiClient.getDashboard(),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('ordinary non-AI requests use the short general timeout', () async {
    final neverCompletes = Completer<http.Response>();

    final mockClient = MockClient((request) {
      return neverCompletes.future;
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      httpClient: mockClient,
      requestTimeout: const Duration(milliseconds: 10),
      chatTimeout: const Duration(milliseconds: 100),
      reflectionTimeout: const Duration(milliseconds: 100),
    );
    addTearDown(apiClient.close);

    await expectLater(
      apiClient.getDashboard(),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('chat requests succeed beyond the general timeout but within the chat timeout', () async {
    final mockClient = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return http.Response('{"ok":true}', 200);
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      httpClient: mockClient,
      requestTimeout: const Duration(milliseconds: 10),
      chatTimeout: const Duration(milliseconds: 100),
      reflectionTimeout: const Duration(milliseconds: 100),
    );
    addTearDown(apiClient.close);

    final result = await apiClient.sendChat(
      conversation: const [
        {'role': 'user', 'content': 'Timeout test'},
      ],
    );

    expect(result['ok'], isTrue);
  });

  test('chat requests still time out beyond the chat timeout', () async {
    final neverCompletes = Completer<http.Response>();
    final mockClient = MockClient((request) => neverCompletes.future);

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      httpClient: mockClient,
      requestTimeout: const Duration(milliseconds: 10),
      chatTimeout: const Duration(milliseconds: 25),
      reflectionTimeout: const Duration(milliseconds: 100),
    );
    addTearDown(apiClient.close);

    await expectLater(
      apiClient.sendChat(
        conversation: const [
          {'role': 'user', 'content': 'Timeout test'},
        ],
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('all reflection endpoints use the longer timeout', () async {
    final reflectionCalls =
        <String, Future<Map<String, dynamic>> Function(ApiClient)>{
          'journal': (client) => client.analyzeJournalEntry(1),
          'daily-checkin': (client) => client.analyzeRecentCheckins(),
          'recovery-insights': (client) =>
              client.getRecoveryInsightsAiReflection(),
          'weekly-review': (client) => client.getWeeklyReviewAiReflection(),
          'monthly-review': (client) => client.getMonthlyReviewAiReflection(),
        };

    for (final entry in reflectionCalls.entries) {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return http.Response('{"ok":true}', 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://example.test',
        httpClient: mockClient,
        requestTimeout: const Duration(milliseconds: 10),
        reflectionTimeout: const Duration(milliseconds: 100),
      );

      addTearDown(apiClient.close);

      final result = await entry.value(apiClient);
      expect(result['ok'], isTrue, reason: entry.key);
    }
  });

  test('reflection requests time out beyond the reflection timeout', () async {
    final neverCompletes = Completer<http.Response>();
    final mockClient = MockClient((request) => neverCompletes.future);
    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      httpClient: mockClient,
      requestTimeout: const Duration(milliseconds: 10),
      reflectionTimeout: const Duration(milliseconds: 25),
    );
    addTearDown(apiClient.close);

    await expectLater(
      apiClient.analyzeJournalEntry(1),
      throwsA(isA<TimeoutException>()),
    );
  });
}
