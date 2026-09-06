import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_fellowship_repository.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(values);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

void main() {
  late Directory directory;
  late LocalRecoveryStore store;
  late LocalFellowshipRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_fellowship_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}'
        '${Platform.pathSeparator}'
        'recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    repository = LocalFellowshipRepository(store: store);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('starts with no contacts', () async {
    final result = await repository.getContacts();

    expect(result['contacts'], isEmpty);
  });

  test('creates and reloads encrypted contact', () async {
    await repository.createContact(
      handle: 'Sponsor Test',
      contactType: 'sponsor',
      contactMethod: '555-0100',
      phone: '555-0100',
      email: 'sponsor@example.test',
      notes: 'Call when struggling',
    );

    final result = await repository.getContacts();

    final contacts = result['contacts'] as List;

    final contact = contacts.first as Map;

    expect(contacts.length, 1);
    expect(contact['id'], 1);
    expect(contact['handle'], 'Sponsor Test');
    expect(contact['contact_type'], 'sponsor');
    expect(contact['contact_method'], '555-0100');
    expect(contact['phone'], '555-0100');
    expect(contact['email'], 'sponsor@example.test');

    final encrypted = await store.dataFile.readAsString();

    expect(encrypted, isNot(contains('Sponsor Test')));

    expect(encrypted, isNot(contains('555-0100')));
  });

  test('updates contact details locally', () async {
    final created = await repository.createContact(
      handle: 'Original',
      contactType: 'fellowship',
    );

    final id = (created['contact'] as Map)['id'] as int;

    await repository.updateContact(
      contactId: id,
      handle: 'Updated',
      contactType: 'sponsor',
      contactMethod: 'Signal',
      phone: '555-0101',
      email: 'updated@example.test',
      notes: 'Updated note',
    );

    final result = await repository.getContacts();

    final contact = (result['contacts'] as List).first as Map;

    expect(contact['handle'], 'Updated');

    expect(contact['contact_type'], 'sponsor');

    expect(contact['contact_method'], 'Signal');
    expect(contact['phone'], '555-0101');
    expect(contact['email'], 'updated@example.test');
    expect(contact['notes'], 'Updated note');
  });

  test('legacy contact_method-only contact remains readable', () async {
    await store.write({
      'fellowship_contacts': [
        {
          'id': 4,
          'handle': 'Legacy Contact',
          'contact_type': 'fellowship',
          'contact_method': 'Signal',
          'notes': 'Keep this value',
          'active': true,
        },
      ],
    });

    final result = await repository.getContacts();
    final contact = (result['contacts'] as List).single as Map;

    expect(contact['contact_method'], 'Signal');
    expect(contact.containsKey('phone'), isFalse);
    expect(contact.containsKey('email'), isFalse);
  });

  test(
    'updating a legacy contact preserves contact_method when omitted',
    () async {
      await store.write({
        'fellowship_contacts': [
          {
            'id': 4,
            'handle': 'Legacy Contact',
            'contact_type': 'fellowship',
            'contact_method': 'Phone',
            'notes': 'Original note',
            'active': true,
          },
        ],
      });

      await repository.updateContact(
        contactId: 4,
        handle: 'Updated Contact',
        contactType: 'sponsor',
        notes: 'Updated note',
      );

      final contact =
          ((await repository.getContacts())['contacts'] as List).single as Map;

      expect(contact['contact_method'], 'Phone');
      expect(contact['handle'], 'Updated Contact');
    },
  );

  test(
    'updating phone and email preserves identity and unknown fields',
    () async {
      final createdAt = '2026-09-01T12:00:00Z';

      await store.write({
        'fellowship_contacts': [
          {
            'id': 8,
            'handle': 'Original Contact',
            'contact_type': 'sponsor',
            'contact_method': 'Text',
            'notes': 'Original note',
            'active': false,
            'created_at': createdAt,
            'custom_field': 'preserve me',
          },
        ],
      });

      await repository.updateContact(
        contactId: 8,
        handle: 'Updated Contact',
        contactType: 'sponsor',
        phone: '555-0102',
        email: 'updated@example.test',
        notes: 'Updated note',
      );

      final contact =
          ((await repository.getContacts())['contacts'] as List).single as Map;

      expect(contact['id'], 8);
      expect(contact['created_at'], createdAt);
      expect(contact['active'], isFalse);
      expect(contact['notes'], 'Updated note');
      expect(contact['contact_method'], 'Text');
      expect(contact['phone'], '555-0102');
      expect(contact['email'], 'updated@example.test');
      expect(contact['custom_field'], 'preserve me');
      expect(contact['updated_at'], isA<String>());
    },
  );

  test('reading contacts does not mutate the encrypted document', () async {
    await store.write({
      'fellowship_contacts': [
        {
          'id': 3,
          'handle': 'Legacy Contact',
          'contact_type': 'fellowship',
          'contact_method': 'arbitrary text',
          'active': true,
        },
      ],
    });
    final before = await store.dataFile.readAsString();

    await repository.getContacts();

    final after = await store.dataFile.readAsString();
    expect(after, before);
  });

  test('inactive contacts are excluded from recommendations', () async {
    final first = await repository.createContact(
      handle: 'First',
      contactType: 'sponsor',
    );

    await repository.createContact(handle: 'Second', contactType: 'fellowship');

    final firstId = (first['contact'] as Map)['id'] as int;

    await repository.setContactActive(contactId: firstId, active: false);

    final recommended = await repository.getRecommendedContacts();

    final contacts = recommended['contacts'] as List;

    expect(contacts.length, 1);

    expect((contacts.first as Map)['handle'], 'Second');
  });

  test('contact changes preserve other recovery data', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'goals': [
        {'id': 1, 'text': 'Keep this goal'},
      ],
      'routines': [
        {'id': 1, 'text': 'Keep this routine'},
      ],
    });

    await repository.createContact(
      handle: 'Recovery Friend',
      contactType: 'fellowship',
    );

    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');

    expect(((data['goals'] as List).first as Map)['text'], 'Keep this goal');

    expect(
      ((data['routines'] as List).first as Map)['text'],
      'Keep this routine',
    );
  });
}
