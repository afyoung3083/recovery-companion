import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/contact_profile_screen.dart';
import 'package:mobile/fellowship_contact_actions.dart';
import 'package:mobile/local_fellowship_repository.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<Map<String, String>> readAll() async => {};

  @override
  Future<void> write({required String key, required String value}) async {}
}

class FakeLocalFellowshipRepository extends LocalFellowshipRepository {
  FakeLocalFellowshipRepository(Map<String, dynamic> contact)
    : _contact = Map<String, dynamic>.from(contact),
      super(
        store: LocalRecoveryStore(
          dataFile: File('unused-contact-profile-test.enc'),
          keyStore: MemorySecureKeyValueStore(),
        ),
      );

  Map<String, dynamic> _contact;

  @override
  Future<Map<String, dynamic>> updateContact({
    required int contactId,
    required String handle,
    required String contactType,
    String? contactMethod,
    String phone = '',
    String email = '',
    String notes = '',
  }) async {
    _contact = {
      ..._contact,
      'handle': handle,
      'contact_type': contactType,
      ...?contactMethod == null ? null : {'contact_method': contactMethod},
      'phone': phone,
      'email': email,
      'notes': notes,
    };
    return {'contact': Map<String, dynamic>.from(_contact)};
  }

  @override
  Future<Map<String, dynamic>> setContactActive({
    required int contactId,
    required bool active,
  }) async {
    _contact = {..._contact, 'active': active};
    return {'contact': Map<String, dynamic>.from(_contact)};
  }
}

Map<String, dynamic> contact() {
  return {
    'id': 2,
    'handle': 'Sponsor Bob',
    'contact_type': 'sponsor',
    'contact_method': '555-0100',
    'phone': '555-0100',
    'email': 'sponsor@example.test',
    'notes': 'Call when isolating.',
    'active': true,
  };
}

Map<String, dynamic> legacyOnlyContact() {
  final value = contact();
  value.remove('phone');
  value.remove('email');
  return value;
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

Future<void> scrollUntilBuiltFinite(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));
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

    final phoneField = find.byKey(const ValueKey('contact-profile-phone'));

    final phoneWidget = tester.widget<TextField>(phoneField);

    expect(phoneWidget.controller?.text, '555-0100');

    final emailField = find.byKey(const ValueKey('contact-profile-email'));
    final emailWidget = tester.widget<TextField>(emailField);

    expect(emailWidget.controller?.text, 'sponsor@example.test');

    expect(
      find.byKey(const ValueKey('contact-profile-legacy-method')),
      findsOneWidget,
    );

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
        expect(body['contact_method'], '555-0100');

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
        home: ContactProfileScreen(
          apiClient: apiClient,
          contact: legacyOnlyContact(),
        ),
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

  testWidgets(
    'local profile edits phone and email while preserving legacy info',
    (tester) async {
      final repository = FakeLocalFellowshipRepository(contact());
      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: MockClient((_) async => http.Response('{}', 500)),
      );
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ContactProfileScreen(
            apiClient: apiClient,
            contact: contact(),
            localRepository: repository,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byKey(const ValueKey('contact-profile-phone')),
        '555-0111',
      );
      await tester.enterText(
        find.byKey(const ValueKey('contact-profile-email')),
        'updated@example.test',
      );
      await scrollUntilBuiltFinite(
        tester,
        find.byKey(const ValueKey('contact-profile-save')),
      );
      await tester.tap(find.byKey(const ValueKey('contact-profile-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository._contact['phone'], '555-0111');
      expect(repository._contact['email'], 'updated@example.test');
      expect(repository._contact['contact_method'], '555-0100');
    },
  );

  testWidgets('clearing legacy contact info explicitly updates it', (
    tester,
  ) async {
    final repository = FakeLocalFellowshipRepository(contact());
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(
          apiClient: apiClient,
          contact: contact(),
          localRepository: repository,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('contact-profile-legacy-method')),
      '',
    );
    await scrollUntilBuiltFinite(
      tester,
      find.byKey(const ValueKey('contact-profile-save')),
    );
    await tester.tap(find.byKey(const ValueKey('contact-profile-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository._contact['contact_method'], isEmpty);
  });

  testWidgets('phone-only contact shows Call and Text but no Email', (
    tester,
  ) async {
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    final phoneOnly = contact();
    phoneOnly.remove('email');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(apiClient: apiClient, contact: phoneOnly),
      ),
    );
    await tester.pumpAndSettle();

    await scrollUntilBuiltFinite(
      tester,
      find.byKey(const ValueKey('contact-profile-action-call')),
    );

    expect(
      find.byKey(const ValueKey('contact-profile-action-call')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('contact-profile-action-text')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('contact-profile-action-email')),
      findsNothing,
    );
  });

  testWidgets('email-only contact shows Email but no Call or Text', (
    tester,
  ) async {
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    final emailOnly = contact();
    emailOnly.remove('phone');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(apiClient: apiClient, contact: emailOnly),
      ),
    );
    await tester.pumpAndSettle();

    await scrollUntilBuiltFinite(
      tester,
      find.byKey(const ValueKey('contact-profile-action-email')),
    );

    expect(
      find.byKey(const ValueKey('contact-profile-action-call')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('contact-profile-action-text')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('contact-profile-action-email')),
      findsOneWidget,
    );
  });

  testWidgets('phone and email contact shows all three native actions', (
    tester,
  ) async {
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(apiClient: apiClient, contact: contact()),
      ),
    );
    await tester.pumpAndSettle();

    await scrollUntilBuiltFinite(
      tester,
      find.byKey(const ValueKey('contact-profile-action-email')),
    );

    expect(
      find.byKey(const ValueKey('contact-profile-action-call')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('contact-profile-action-text')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('contact-profile-action-email')),
      findsOneWidget,
    );
  });

  testWidgets('legacy-only contact shows no native actions', (tester) async {
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(
          apiClient: apiClient,
          contact: legacyOnlyContact(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('contact-profile-action-call')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('contact-profile-action-text')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('contact-profile-action-email')),
      findsNothing,
    );
  });

  testWidgets('tapping Call requests a tel URI', (tester) async {
    final requested = <Uri>[];
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(
          apiClient: apiClient,
          contact: contact(),
          contactActions: FellowshipContactActions(
            launcher: (uri) async {
              requested.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrollUntilBuiltFinite(
      tester,
      find.byKey(const ValueKey('contact-profile-action-call')),
    );
    await tester.tap(find.byKey(const ValueKey('contact-profile-action-call')));
    await tester.pumpAndSettle();

    expect(requested, [Uri.parse('tel:555-0100')]);
  });

  testWidgets('tapping Text requests an sms URI', (tester) async {
    final requested = <Uri>[];
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(
          apiClient: apiClient,
          contact: contact(),
          contactActions: FellowshipContactActions(
            launcher: (uri) async {
              requested.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrollUntilBuiltFinite(
      tester,
      find.byKey(const ValueKey('contact-profile-action-text')),
    );
    await tester.tap(find.byKey(const ValueKey('contact-profile-action-text')));
    await tester.pumpAndSettle();

    expect(requested, [Uri.parse('sms:555-0100')]);
  });

  testWidgets('tapping Email requests a mailto URI', (tester) async {
    final requested = <Uri>[];
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(
          apiClient: apiClient,
          contact: contact(),
          contactActions: FellowshipContactActions(
            launcher: (uri) async {
              requested.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrollUntilBuiltFinite(
      tester,
      find.byKey(const ValueKey('contact-profile-action-email')),
    );
    await tester.tap(
      find.byKey(const ValueKey('contact-profile-action-email')),
    );
    await tester.pumpAndSettle();

    expect(requested, [Uri.parse('mailto:sponsor@example.test')]);
  });

  testWidgets('launch failure shows a concise error message', (tester) async {
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ContactProfileScreen(
          apiClient: apiClient,
          contact: contact(),
          contactActions: FellowshipContactActions(
            launcher: (uri) async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await scrollUntilBuiltFinite(
      tester,
      find.byKey(const ValueKey('contact-profile-action-call')),
    );
    await tester.tap(find.byKey(const ValueKey('contact-profile-action-call')));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the phone app.'), findsOneWidget);
  });
}
