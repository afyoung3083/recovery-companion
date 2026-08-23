import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/chat_screen.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('chat keeps ordered conversation across turns', (tester) async {
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
        home: Scaffold(body: ChatScreen(apiClient: apiClient)),
      ),
    );

    expect(
      find.text(
        'This conversation is session-only and '
        'is not saved as chat history.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-input')),
      'I had a hard morning.',
    );

    await tester.tap(find.byKey(const ValueKey('chat-send')));

    await tester.pumpAndSettle();

    expect(find.text('I had a hard morning.'), findsOneWidget);

    expect(find.text('What felt hardest about it?'), findsOneWidget);

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

  testWidgets('failed chat send is removed and text is restored', (
    tester,
  ) async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'detail': 'Unable to generate a Recovery Companion response.',
        }),
        502,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatScreen(apiClient: apiClient)),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-input')),
      'Please keep this for retry.',
    );

    await tester.tap(find.byKey(const ValueKey('chat-send')));

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-message-user-0')), findsNothing);

    expect(find.byKey(const ValueKey('chat-error')), findsOneWidget);

    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-input')),
    );

    expect(input.controller!.text, 'Please keep this for retry.');

    apiClient.close();
  });
}
