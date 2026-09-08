import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/fellowship_contact_actions.dart';
import 'package:mobile/fellowship_screen.dart';
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
  FakeLocalFellowshipRepository({
    List<Map<String, dynamic>> contacts = const [],
  }) : _contacts = contacts
           .map((contact) => Map<String, dynamic>.from(contact))
           .toList(),
       super(
         store: LocalRecoveryStore(
           dataFile: File('unused-fellowship-widget-test.enc'),
           keyStore: MemorySecureKeyValueStore(),
         ),
       );

  final List<Map<String, dynamic>> _contacts;

  Map<String, dynamic>? createdContact;
  Map<String, dynamic>? updatedContact;

  @override
  Future<Map<String, dynamic>> getContacts() async {
    return {'contacts': _copyContacts(_contacts)};
  }

  @override
  Future<Map<String, dynamic>> getRecommendedContacts() async {
    return {
      'contacts': _copyContacts(
        _contacts
            .where((contact) => contact['active'] != false)
            .take(3)
            .toList(),
      ),
    };
  }

  @override
  Future<Map<String, dynamic>> createContact({
    required String handle,
    required String contactType,
    String contactMethod = '',
    String phone = '',
    String email = '',
    String notes = '',
  }) async {
    createdContact = {
      'id': 1,
      'handle': handle,
      'contact_type': contactType,
      'contact_method': contactMethod,
      'phone': phone,
      'email': email,
      'notes': notes,
      'active': true,
    };
    _contacts.add(createdContact!);
    return {'contact': Map<String, dynamic>.from(createdContact!)};
  }

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
    final index = _contacts.indexWhere((contact) => contact['id'] == contactId);
    final updated = {
      ..._contacts[index],
      'handle': handle,
      'contact_type': contactType,
      ...?contactMethod == null ? null : {'contact_method': contactMethod},
      'phone': phone,
      'email': email,
      'notes': notes,
    };
    _contacts[index] = updated;
    updatedContact = updated;
    return {'contact': Map<String, dynamic>.from(updated)};
  }

  @override
  Future<Map<String, dynamic>> setContactActive({
    required int contactId,
    required bool active,
  }) async {
    final index = _contacts.indexWhere((contact) => contact['id'] == contactId);
    _contacts[index] = {..._contacts[index], 'active': active};
    return {'contact': Map<String, dynamic>.from(_contacts[index])};
  }

  List<Map<String, dynamic>> _copyContacts(
    List<Map<String, dynamic>> contacts,
  ) {
    return contacts.map(Map<String, dynamic>.from).toList();
  }
}

Future<void> pumpFellowship(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> scrollUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 16; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw TestFailure('Expected Fellowship widget did not become visible.');
}

ApiClient testApiClient() {
  return ApiClient(
    baseUrl: 'http://example.test',
    apiToken: 'test-token',
    httpClient: MockClient((_) async => http.Response('{}', 500)),
  );
}

void main() {
  testWidgets(
    'add contact presents and saves separate phone and email fields',
    (tester) async {
      final repository = FakeLocalFellowshipRepository();
      final apiClient = testApiClient();
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: FellowshipScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      );
      await pumpFellowship(tester);

      await scrollUntilVisible(
        tester,
        find.byKey(const ValueKey('fellowship-add-phone')),
      );

      expect(
        find.byKey(const ValueKey('fellowship-add-phone')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('fellowship-add-email')),
        findsOneWidget,
      );
      expect(find.text('Contact method'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('fellowship-add-handle')),
        'Sponsor Lee',
      );
      await tester.enterText(
        find.byKey(const ValueKey('fellowship-add-phone')),
        '555-0199',
      );
      await tester.enterText(
        find.byKey(const ValueKey('fellowship-add-email')),
        'lee@example.test',
      );
      tester.testTextInput.hide();
      await tester.pump(const Duration(milliseconds: 100));
      final addButton = find.byKey(const ValueKey('fellowship-add-submit'));
      await scrollUntilVisible(tester, addButton);
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await pumpFellowship(tester);

      expect(repository.createdContact?['phone'], '555-0199');
      expect(repository.createdContact?['email'], 'lee@example.test');
      expect(repository.createdContact?['contact_method'], '');
    },
  );

  testWidgets(
    'contact rows show labeled phone and email without question marks',
    (tester) async {
      final repository = FakeLocalFellowshipRepository(
        contacts: [
          {
            'id': 1,
            'handle': 'Brent',
            'contact_type': 'sponsor',
            'phone': '555-0100',
            'email': 'brent@example.test',
            'active': true,
          },
        ],
      );
      final apiClient = testApiClient();
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: FellowshipScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      );
      await pumpFellowship(tester);

      await scrollUntilVisible(tester, find.text('Brent'));

      expect(
        find.text('Sponsor\nPhone: 555-0100\nEmail: brent@example.test'),
        findsOneWidget,
      );
      expect(find.textContaining('?'), findsNothing);
    },
  );

  testWidgets('legacy contact method is labeled as other contact info', (
    tester,
  ) async {
    final repository = FakeLocalFellowshipRepository(
      contacts: [
        {
          'id': 1,
          'handle': 'Don',
          'contact_type': 'fellowship',
          'contact_method': 'Signal',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FellowshipScreen(
          apiClient: apiClient,
          localRepository: repository,
        ),
      ),
    );
    await pumpFellowship(tester);

    await scrollUntilVisible(tester, find.text('Don'));

    expect(find.text('Fellowship\nOther contact info: Signal'), findsOneWidget);
    expect(find.textContaining('?'), findsNothing);
  });

  testWidgets('structured phone renders call and text quick actions', (
    tester,
  ) async {
    final repository = FakeLocalFellowshipRepository(
      contacts: [
        {
          'id': 3,
          'handle': 'Phone Contact',
          'contact_type': 'sponsor',
          'phone': '555-0100',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FellowshipScreen(
          apiClient: apiClient,
          localRepository: repository,
        ),
      ),
    );
    await pumpFellowship(tester);

    await scrollUntilVisible(
      tester,
      find.byKey(const ValueKey('fellowship-contact-call-3')),
    );

    expect(
      find.byKey(const ValueKey('fellowship-contact-call-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fellowship-contact-text-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('fellowship-contact-email-3')),
      findsNothing,
    );
  });

  testWidgets('structured email renders an email quick action', (tester) async {
    final repository = FakeLocalFellowshipRepository(
      contacts: [
        {
          'id': 4,
          'handle': 'Email Contact',
          'contact_type': 'sponsor',
          'email': 'contact@example.test',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FellowshipScreen(
          apiClient: apiClient,
          localRepository: repository,
        ),
      ),
    );
    await pumpFellowship(tester);

    await scrollUntilVisible(
      tester,
      find.byKey(const ValueKey('fellowship-contact-email-4')),
    );

    expect(
      find.byKey(const ValueKey('fellowship-contact-call-4')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fellowship-contact-text-4')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fellowship-contact-email-4')),
      findsOneWidget,
    );
  });

  testWidgets('legacy-only contact renders no native quick action', (
    tester,
  ) async {
    final repository = FakeLocalFellowshipRepository(
      contacts: [
        {
          'id': 5,
          'handle': 'Legacy Contact',
          'contact_type': 'fellowship',
          'contact_method': '555-0100',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FellowshipScreen(
          apiClient: apiClient,
          localRepository: repository,
        ),
      ),
    );
    await pumpFellowship(tester);

    await scrollUntilVisible(tester, find.text('Legacy Contact'));

    expect(
      find.byKey(const ValueKey('fellowship-contact-call-5')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fellowship-contact-text-5')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fellowship-contact-email-5')),
      findsNothing,
    );
  });

  testWidgets('tapping a quick action does not navigate to Contact Profile', (
    tester,
  ) async {
    final repository = FakeLocalFellowshipRepository(
      contacts: [
        {
          'id': 6,
          'handle': 'Phone Contact',
          'contact_type': 'sponsor',
          'phone': '555-0100',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FellowshipScreen(
          apiClient: apiClient,
          localRepository: repository,
        ),
      ),
    );
    await pumpFellowship(tester);

    await scrollUntilVisible(
      tester,
      find.byKey(const ValueKey('fellowship-contact-call-6')),
    );
    await tester.tap(find.byKey(const ValueKey('fellowship-contact-call-6')));
    await pumpFellowship(tester);

    expect(find.byKey(const ValueKey('contact-profile-screen')), findsNothing);
  });

  testWidgets('normal row tap still opens Contact Profile', (tester) async {
    final repository = FakeLocalFellowshipRepository(
      contacts: [
        {
          'id': 7,
          'handle': 'Phone Contact',
          'contact_type': 'sponsor',
          'phone': '555-0100',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FellowshipScreen(
          apiClient: apiClient,
          localRepository: repository,
        ),
      ),
    );
    await pumpFellowship(tester);

    await scrollUntilVisible(
      tester,
      find.byKey(const ValueKey('fellowship-contact-7')),
    );
    await tester.tap(find.byKey(const ValueKey('fellowship-contact-7')));
    await pumpFellowship(tester);

    expect(
      find.byKey(const ValueKey('contact-profile-screen')),
      findsOneWidget,
    );
  });

  testWidgets('quick action launch failure is handled safely', (tester) async {
    final repository = FakeLocalFellowshipRepository(
      contacts: [
        {
          'id': 8,
          'handle': 'Phone Contact',
          'contact_type': 'sponsor',
          'phone': '555-0100',
          'active': true,
        },
      ],
    );
    final apiClient = testApiClient();
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FellowshipScreen(
            apiClient: apiClient,
            localRepository: repository,
            contactActions: FellowshipContactActions(
              launcher: (uri) async => false,
            ),
          ),
        ),
      ),
    );
    await pumpFellowship(tester);

    await scrollUntilVisible(
      tester,
      find.byKey(const ValueKey('fellowship-contact-call-8')),
    );
    await tester.tap(find.byKey(const ValueKey('fellowship-contact-call-8')));
    await pumpFellowship(tester);

    expect(find.text('Could not open the phone app.'), findsOneWidget);
  });
}
