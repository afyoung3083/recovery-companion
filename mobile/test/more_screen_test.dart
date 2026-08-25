import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/more_screen.dart';

Future<void> scrollDownUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));

    await tester.pumpAndSettle();
  }

  throw TestFailure('Expected widget did not become visible.');
}

void main() {
  testWidgets('More screen groups recovery tools by purpose', (tester) async {
    final mockClient = MockClient((request) async {
      return http.Response('{}', 200);
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: mockClient,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: MoreScreen(apiClient: apiClient)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);

    expect(find.text('Daily Recovery'), findsOneWidget);

    await scrollDownUntilVisible(tester, find.text('Connection'));

    expect(find.text('Connection'), findsOneWidget);

    expect(find.text('Recovery Companion'), findsOneWidget);

    await scrollDownUntilVisible(tester, find.text('Program'));

    expect(find.text('Program'), findsOneWidget);

    expect(find.text('Step Work'), findsOneWidget);

    await scrollDownUntilVisible(tester, find.text('Account'));

    expect(find.text('Account'), findsOneWidget);

    expect(find.text('Profile'), findsOneWidget);

    expect(find.text('Settings & Privacy'), findsOneWidget);

    apiClient.close();
  });
}
