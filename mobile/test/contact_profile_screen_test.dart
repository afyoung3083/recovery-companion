import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/contact_profile_screen.dart';

Map<String, dynamic> contact() {
  return {
    'id': 2,
    'handle': 'Sponsor Bob',
    'contact_type': 'sponsor',
    'contact_method': '555-0100',
    'notes': 'Call when isolating.',
    'active': true,
  };
}

Future<void> scrollUntilBuilt(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));

    await tester.pumpAndSettle();
  }

  throw TestFailure('Expected contact profile widget did not become visible.');
}

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  testWidgets('contact profile displays editable fellowship details', (
    tester,
  ) async {
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(apiClient: apiClient, contact: contact()),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('contact-profile-screen')),
      findsOneWidget,
    );

    expect(find.text('Sponsor Bob'), findsNWidgets(2));

    final methodField = find.byKey(const ValueKey('contact-profile-method'));

    final methodWidget = tester.widget<TextField>(methodField);

    expect(methodWidget.controller?.text, '555-0100');

    final notesField = find.byKey(const ValueKey('contact-profile-notes'));

    final notesWidget = tester.widget<TextField>(notesField);

    expect(notesWidget.controller?.text, 'Call when isolating.');

    apiClient.close();
  });

  testWidgets('contact profile saves edits and active status', (tester) async {
    var updateCount = 0;
    var activeCount = 0;

    final mockClient = MockClient((request) async {
      if (request.method == 'PUT' && request.url.path == '/fellowship/2') {
        updateCount += 1;

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['handle'], 'Sponsor Robert');

        return http.Response(
          jsonEncode({
            'contact': {...contact(), 'handle': 'Sponsor Robert'},
          }),
          200,
        );
      }

      if (request.method == 'PUT' &&
          request.url.path == '/fellowship/2/active') {
        activeCount += 1;

        expect(jsonDecode(request.body), {'active': false});

        return http.Response(
          jsonEncode({
            'contact': {
              ...contact(),
              'handle': 'Sponsor Robert',
              'active': false,
            },
          }),
          200,
        );
      }

      throw StateError(
        'Unexpected request: '
        '${request.method} ${request.url}',
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
        home: ContactProfileScreen(apiClient: apiClient, contact: contact()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('contact-profile-handle')),
      'Sponsor Robert',
    );

    final activeSwitch = find.byKey(
      const ValueKey('contact-profile-active-switch'),
    );

    await scrollUntilBuilt(tester, activeSwitch);

    await tester.tap(activeSwitch);
    await tester.pumpAndSettle();

    final saveButton = find.byKey(const ValueKey('contact-profile-save'));

    await scrollUntilBuilt(tester, saveButton);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(updateCount, 1);
    expect(activeCount, 1);

    expect(find.text('Contact profile saved.'), findsOneWidget);

    apiClient.close();
  });
}
