import 'local_recovery_store.dart';

class LocalFellowshipRepository {
  LocalFellowshipRepository({required this.store});

  final LocalRecoveryStore store;

  Future<Map<String, dynamic>> getContacts() async {
    final contacts = await _readContacts();

    return {'contacts': contacts};
  }

  Future<Map<String, dynamic>> getRecommendedContacts() async {
    final contacts = await _readContacts();

    final recommended = contacts
        .where((contact) => contact['active'] != false)
        .take(3)
        .map((contact) => Map<String, dynamic>.from(contact))
        .toList();

    return {'contacts': recommended};
  }

  Future<Map<String, dynamic>> createContact({
    required String handle,
    required String contactType,
    String contactMethod = '',
    String notes = '',
  }) async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final contacts = _contactsFromData(data);

    var nextId = 1;

    for (final contact in contacts) {
      final id = contact['id'];

      if (id is int && id >= nextId) {
        nextId = id + 1;
      }
    }

    final contact = <String, dynamic>{
      'id': nextId,
      'handle': handle,
      'contact_type': contactType,
      'contact_method': contactMethod,
      'notes': notes,
      'active': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    contacts.add(contact);
    data['fellowship_contacts'] = contacts;

    await store.write(data);

    return {'contact': contact};
  }

  Future<Map<String, dynamic>> updateContact({
    required int contactId,
    required String handle,
    required String contactType,
    String contactMethod = '',
    String notes = '',
  }) async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final contacts = _contactsFromData(data);

    final index = contacts.indexWhere((contact) => contact['id'] == contactId);

    if (index < 0) {
      throw StateError('Contact $contactId was not found.');
    }

    contacts[index] = {
      ...contacts[index],
      'handle': handle,
      'contact_type': contactType,
      'contact_method': contactMethod,
      'notes': notes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    data['fellowship_contacts'] = contacts;

    await store.write(data);

    return {'contact': contacts[index]};
  }

  Future<Map<String, dynamic>> setContactActive({
    required int contactId,
    required bool active,
  }) async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final contacts = _contactsFromData(data);

    final index = contacts.indexWhere((contact) => contact['id'] == contactId);

    if (index < 0) {
      throw StateError('Contact $contactId was not found.');
    }

    contacts[index] = {
      ...contacts[index],
      'active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    data['fellowship_contacts'] = contacts;

    await store.write(data);

    return {'contact': contacts[index]};
  }

  Future<List<Map<String, dynamic>>> _readContacts() async {
    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    return _contactsFromData(data);
  }

  List<Map<String, dynamic>> _contactsFromData(Map<String, dynamic> data) {
    final rawContacts = data['fellowship_contacts'];

    if (rawContacts is! List) {
      return [];
    }

    return rawContacts
        .whereType<Map>()
        .map((contact) => Map<String, dynamic>.from(contact))
        .toList();
  }
}
