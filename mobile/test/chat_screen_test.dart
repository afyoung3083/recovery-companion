import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/chat_screen.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('Chat shows session and human connection boundaries', (
    tester,
  ) async {
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ChatScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Recovery Companion'), findsOneWidget);

    expect(find.textContaining('session-only'), findsOneWidget);

    expect(
      find.textContaining('does not replace your sponsor'),
      findsOneWidget,
    );

    apiClient.close();
  });

  testWidgets('Chat sends conversation and renders response', (tester) async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');

      expect(request.url.path, '/chat');

      expect(request.headers['Authorization'], 'Bearer $token');

      final body = jsonDecode(request.body) as Map<String, dynamic>;

      final conversation = body['conversation'] as List<dynamic>;

      expect(conversation.length, 1);

      expect(conversation.first['role'], 'user');

      expect(conversation.first['content'], 'I feel stuck today.');

      return http.Response(
        jsonEncode({
          'response': 'What feels most important about being stuck right now?',
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ChatScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chat-input')),
      'I feel stuck today.',
    );

    await tester.tap(find.byKey(const ValueKey('chat-send')));

    await tester.pumpAndSettle();

    expect(find.text('I feel stuck today.'), findsOneWidget);

    expect(
      find.text('What feels most important about being stuck right now?'),
      findsOneWidget,
    );

    apiClient.close();
  });

  testWidgets('Chat restores message after send failure', (tester) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'detail': 'Internal error detail'}),
        500,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ChatScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('chat-input'));

    await tester.enterText(input, 'Please keep this message.');

    await tester.tap(find.byKey(const ValueKey('chat-send')));

    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(input);

    expect(field.controller?.text, 'Please keep this message.');

    expect(
      find.text('Unable to send your message. Please try again.'),
      findsOneWidget,
    );

    expect(find.textContaining('Internal error detail'), findsNothing);

    apiClient.close();
  });
  testWidgets('Chat keeps ordered conversation across turns', (tester) async {
    var requestCount = 0;

    final mockClient = MockClient((request) async {
      requestCount += 1;

      final body = jsonDecode(request.body) as Map<String, dynamic>;

      final conversation = body['conversation'] as List<dynamic>;

      if (requestCount == 1) {
        expect(conversation, [
          {'role': 'user', 'content': 'I had a hard morning.'},
        ]);

        return http.Response(
          jsonEncode({'response': 'What felt hardest about it?'}),
          200,
        );
      }

      expect(conversation, [
        {'role': 'user', 'content': 'I had a hard morning.'},
        {'role': 'assistant', 'content': 'What felt hardest about it?'},
        {'role': 'user', 'content': 'I wanted to isolate.'},
      ]);

      return http.Response(
        jsonEncode({
          'response': 'It sounds like isolation was pulling at you.',
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ChatScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chat-input')),
      'I had a hard morning.',
    );

    await tester.tap(find.byKey(const ValueKey('chat-send')));

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chat-input')),
      'I wanted to isolate.',
    );

    await tester.tap(find.byKey(const ValueKey('chat-send')));

    await tester.pumpAndSettle();

    expect(requestCount, 2);

    expect(
      find.text('It sounds like isolation was pulling at you.'),
      findsOneWidget,
    );

    apiClient.close();
  });
}
