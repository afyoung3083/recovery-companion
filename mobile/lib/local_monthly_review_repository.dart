import 'local_recovery_store.dart';

class LocalMonthlyReviewRepository {
  LocalMonthlyReviewRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LocalRecoveryStore store;
  final DateTime Function() _now;

  Future<Map<String, dynamic>> getCurrentReview() async {
    final snapshot = await _buildSnapshot();

    if (snapshot == null) {
      return {'review': ''};
    }

    final review =
        'Most recent ${snapshot['weekly_reviews_included']} saved weeks: '
        '${snapshot['checkin_days']} check-in days ? '
        '${snapshot['journal_entries']} journal entries.';

    return {'review': review, 'snapshot': snapshot};
  }

  Future<Map<String, dynamic>> buildAiReflectionPayload() async {
    final current = await getCurrentReview();

    final summary = (current['review'] ?? '').toString().trim();

    return {'summary': summary};
  }

  Future<Map<String, dynamic>> saveSnapshot() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final snapshot = await _buildSnapshotFromData(data);

    if (snapshot == null) {
      throw StateError('At least one saved weekly review is required.');
    }

    final rawHistory = data['monthly_reviews'];

    final history = rawHistory is List
        ? rawHistory
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    final snapshotDate = snapshot['snapshot_date'];

    final existingIndex = history.indexWhere(
      (item) => item['snapshot_date'] == snapshotDate,
    );

    if (existingIndex >= 0) {
      history[existingIndex] = snapshot;
    } else {
      history.add(snapshot);
    }

    data['monthly_reviews'] = history;

    await store.write(data);

    return {'snapshot': snapshot};
  }

  Future<Map<String, dynamic>> getHistory() async {
    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    final rawHistory = data['monthly_reviews'];

    final history = rawHistory is List
        ? rawHistory
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    history.sort(
      (a, b) => (a['snapshot_date'] ?? '').toString().compareTo(
        (b['snapshot_date'] ?? '').toString(),
      ),
    );

    return {'history': history};
  }

  Future<Map<String, dynamic>> getComparison() async {
    final result = await getHistory();

    final history = (result['history'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (history.length < 2) {
      return {'comparison': ''};
    }

    final previous = history[history.length - 2];
    final latest = history.last;

    final checkinDelta =
        (latest['checkin_days'] as int? ?? 0) -
        (previous['checkin_days'] as int? ?? 0);

    final journalDelta =
        (latest['journal_entries'] as int? ?? 0) -
        (previous['journal_entries'] as int? ?? 0);

    return {
      'comparison':
          'Compared with the previous saved monthly snapshot: '
          '${_signed(checkinDelta)} check-in days and '
          '${_signed(journalDelta)} journal entries.',
    };
  }

  Future<Map<String, dynamic>?> _buildSnapshot() async {
    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    return _buildSnapshotFromData(data);
  }

  Future<Map<String, dynamic>?> _buildSnapshotFromData(
    Map<String, dynamic> data,
  ) async {
    final rawWeekly = data['weekly_reviews'];

    if (rawWeekly is! List) {
      return null;
    }

    final weekly = rawWeekly
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (weekly.isEmpty) {
      return null;
    }

    weekly.sort(
      (a, b) => (a['week_end'] ?? '').toString().compareTo(
        (b['week_end'] ?? '').toString(),
      ),
    );

    final included = weekly.length <= 4
        ? weekly
        : weekly.sublist(weekly.length - 4);

    var checkinDays = 0;
    var journalEntries = 0;

    for (final week in included) {
      checkinDays += week['checkin_days'] as int? ?? 0;

      journalEntries += week['journal_entries'] as int? ?? 0;
    }

    final first = included.first;
    final last = included.last;

    return <String, dynamic>{
      'snapshot_date': _formatDate(_dateOnly(_now())),
      'period_start': (first['week_start'] ?? '').toString(),
      'period_end': (last['week_end'] ?? '').toString(),
      'weekly_reviews_included': included.length,
      'checkin_days': checkinDays,
      'journal_entries': journalEntries,
      'saved_at': _now().toUtc().toIso8601String(),
    };
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();

    return DateTime(local.year, local.month, local.day);
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');

    final month = value.month.toString().padLeft(2, '0');

    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static String _signed(int value) {
    if (value > 0) {
      return '+$value';
    }

    return '$value';
  }
}
