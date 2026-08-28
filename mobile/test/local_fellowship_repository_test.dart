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
      notes: 'Updated note',
    );

    final result = await repository.getContacts();

    final contact = (result['contacts'] as List).first as Map;

    expect(contact['handle'], 'Updated');

    expect(contact['contact_type'], 'sponsor');

    expect(contact['notes'], 'Updated note');
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
