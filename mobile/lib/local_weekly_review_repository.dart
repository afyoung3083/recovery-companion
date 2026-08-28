import 'local_recovery_store.dart';

class LocalWeeklyReviewRepository {
  LocalWeeklyReviewRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LocalRecoveryStore store;
  final DateTime Function() _now;

  Future<Map<String, dynamic>> getCurrentReview() async {
    final snapshot = await _buildSnapshot();

    final review =
        'Past 7 days: '
        '${snapshot['checkin_days']} check-in days ? '
        '${snapshot['journal_entries']} journal entries ? '
        '${snapshot['active_goals']} active goals ? '
        '${snapshot['active_routines']} active routines.';

    return {'review': review, 'snapshot': snapshot};
  }

  Future<Map<String, dynamic>> saveSnapshot() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final rawHistory = data['weekly_reviews'];

    final history = rawHistory is List
        ? rawHistory
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    final snapshot = await _buildSnapshotFromData(data);

    final existingIndex = history.indexWhere(
      (item) => item['week_end'] == snapshot['week_end'],
    );

    if (existingIndex >= 0) {
      history[existingIndex] = snapshot;
    } else {
      history.add(snapshot);
    }

    data['weekly_reviews'] = history;

    await store.write(data);

    return {'snapshot': snapshot};
  }

  Future<Map<String, dynamic>> getHistory() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final rawHistory = data['weekly_reviews'];

    final history = rawHistory is List
        ? rawHistory
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    history.sort(
      (a, b) => (a['week_end'] ?? '').toString().compareTo(
        (b['week_end'] ?? '').toString(),
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
          'Compared with the previous saved week: '
          '${_signed(checkinDelta)} check-in days and '
          '${_signed(journalDelta)} journal entries.',
    };
  }

  Future<Map<String, dynamic>> _buildSnapshot() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    return _buildSnapshotFromData(data);
  }

  Future<Map<String, dynamic>> _buildSnapshotFromData(
    Map<String, dynamic> data,
  ) async {
    final end = _dateOnly(_now());
    final start = end.subtract(const Duration(days: 6));

    final rawCheckins = data['daily_checkins'];
    final checkins = rawCheckins is Map
        ? Map<String, dynamic>.from(rawCheckins)
        : <String, dynamic>{};

    var checkinDays = 0;

    for (final key in checkins.keys) {
      final date = DateTime.tryParse(key);

      if (date != null && !date.isBefore(start) && !date.isAfter(end)) {
        checkinDays++;
      }
    }

    final rawJournal = data['journal_entries'];
    final journal = rawJournal is List
        ? rawJournal.whereType<Map>().toList()
        : <Map>[];

    var journalEntries = 0;

    for (final entry in journal) {
      final rawDate = (entry['date'] ?? entry['created_at'] ?? '').toString();

      final parsed = DateTime.tryParse(rawDate);

      if (parsed == null) {
        continue;
      }

      final date = _dateOnly(parsed);

      if (!date.isBefore(start) && !date.isAfter(end)) {
        journalEntries++;
      }
    }

    final rawGoals = data['goals'];
    final activeGoals = rawGoals is List
        ? rawGoals
              .whereType<Map>()
              .where((goal) => goal['active'] != false)
              .length
        : 0;

    final rawRoutines = data['routines'];
    final activeRoutines = rawRoutines is List
        ? rawRoutines
              .whereType<Map>()
              .where((routine) => routine['active'] != false)
              .length
        : 0;

    return <String, dynamic>{
      'week_start': _formatDate(start),
      'week_end': _formatDate(end),
      'checkin_days': checkinDays,
      'journal_entries': journalEntries,
      'active_goals': activeGoals,
      'active_routines': activeRoutines,
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
