import 'local_recovery_store.dart';

class LocalJournalRepository {
  LocalJournalRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LocalRecoveryStore store;
  final DateTime Function() _now;

  Future<Map<String, dynamic>> getEntries() async {
    final entries = await _readEntries();
    entries.sort(
      (a, b) => (b['created_at'] ?? '').toString().compareTo(
        (a['created_at'] ?? '').toString(),
      ),
    );
    return {'entries': entries};
  }

  Future<Map<String, dynamic>> search(String query) async {
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return getEntries();
    }

    final entries = await _readEntries();

    final matches = entries.where((entry) {
      final text = (entry['text'] ?? '').toString().toLowerCase();
      final rawTags = entry['tags'];
      final tags = rawTags is List
          ? rawTags.map((tag) => tag.toString().toLowerCase())
          : const <String>[];

      return text.contains(normalized) ||
          tags.any((tag) => tag.contains(normalized));
    }).toList();

    matches.sort(
      (a, b) => (b['created_at'] ?? '').toString().compareTo(
        (a['created_at'] ?? '').toString(),
      ),
    );

    return {'entries': matches};
  }

  Future<Map<String, dynamic>> getEntryForAiReflection(int entryId) async {
    final entries = await _readEntries();

    final entry = entries.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == entryId,
      orElse: () => null,
    );

    if (entry == null) {
      throw StateError('Selected local journal entry was not found.');
    }

    final text = (entry['text'] ?? '').toString().trim();

    if (text.isEmpty) {
      throw StateError('Selected local journal entry has no text.');
    }

    return {'entry_id': entryId, 'text': text};
  }

  Future<Map<String, dynamic>> createEntry({
    required String text,
    required List<String> tags,
  }) async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final rawEntries = data['journal_entries'];
    final entries = rawEntries is List
        ? rawEntries
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList()
        : <Map<String, dynamic>>[];

    var nextId = 1;

    for (final entry in entries) {
      final id = entry['id'];
      if (id is int && id >= nextId) {
        nextId = id + 1;
      }
    }

    final now = _now().toUtc();

    final entry = <String, dynamic>{
      'id': nextId,
      'text': text,
      'tags': List<String>.from(tags),
      'created_at': now.toIso8601String(),
      'date': _dateKey(now),
    };

    entries.add(entry);
    data['journal_entries'] = entries;

    await store.write(data);

    return {'entry': entry};
  }

  Future<List<Map<String, dynamic>>> _readEntries() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);
    final rawEntries = data['journal_entries'];

    if (rawEntries is! List) {
      return [];
    }

    return rawEntries
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  String _dateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
