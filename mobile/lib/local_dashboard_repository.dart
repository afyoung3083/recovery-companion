import 'local_recovery_store.dart';

class LocalDashboardRepository {
  LocalDashboardRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LocalRecoveryStore store;
  final DateTime Function() _now;

  Future<Map<String, dynamic>> getDashboard() async {
    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    final profile = _mapFrom(data['profile']);
    final sobrietyDate = (profile['sobriety_date'] ?? '').toString();

    final sobrietyDays = _sobrietyDays(sobrietyDate);

    final todayKey = _formatDate(_dateOnly(_now()));

    final dailyCheckins = _mapFrom(data['daily_checkins']);

    final todayRaw = dailyCheckins[todayKey];

    final today = todayRaw is Map
        ? Map<String, dynamic>.from(todayRaw)
        : <String, dynamic>{};

    const actionKeys = [
      'prayer_meditation',
      'recovery_contact',
      'meeting',
      'step_work',
      'journal',
      'service',
    ];

    final completedCount = actionKeys.where((key) => today[key] == true).length;

    final stepWork = _mapFrom(data['step_work']);

    final currentStep = stepWork['current_step'] is int
        ? stepWork['current_step'] as int
        : 1;

    final assignments = _mapList(stepWork['assignments']);

    final openAssignments = assignments
        .where(
          (assignment) =>
              assignment['step'] == currentStep &&
              assignment['completed'] != true,
        )
        .map((assignment) => Map<String, dynamic>.from(assignment))
        .toList();

    final journal = _mapList(data['journal_entries']);

    journal.sort(
      (a, b) => _journalSortValue(b).compareTo(_journalSortValue(a)),
    );

    final latestJournal = journal.isEmpty ? null : journal.first;

    final fellowship = _mapList(data['fellowship_contacts']);

    final recommendedContacts = fellowship
        .where((contact) => contact['active'] != false)
        .take(3)
        .map((contact) => Map<String, dynamic>.from(contact))
        .toList();

    return {
      'dashboard_data': {
        'sobriety_date': sobrietyDate,
        'sobriety_days': sobrietyDays,
        'today_checkin': {
          'saved': today.isNotEmpty,
          'completed_count': completedCount,
          'total': actionKeys.length,
          'note': (today['note'] ?? '').toString(),
        },
        'current_step': currentStep,
        'open_assignments': openAssignments,
        'latest_journal_entry': latestJournal,
        'recommended_contacts': recommendedContacts,
      },
    };
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is! Map) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) {
      return <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int? _sobrietyDays(String value) {
    if (value.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return null;
    }

    final sobrietyDate = _dateOnly(parsed);
    final today = _dateOnly(_now());

    final days = today.difference(sobrietyDate).inDays;

    return days < 0 ? 0 : days;
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

  String _journalSortValue(Map<String, dynamic> entry) {
    return (entry['created_at'] ?? entry['date'] ?? '').toString();
  }
}
