import 'local_recovery_store.dart';

class LocalInsightsRepository {
  LocalInsightsRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LocalRecoveryStore store;
  final DateTime Function() _now;

  Future<Map<String, dynamic>> getInsights() async {
    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    final profile = _mapFrom(data['profile']);

    final sobrietyDate = (profile['sobriety_date'] ?? '').toString();

    final sobrietyDays = _sobrietyDays(sobrietyDate);

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
        .length;

    final goals = _mapList(data['goals']);

    final activeGoals = goals.where((goal) => goal['active'] != false).length;

    final checkinDays = _recentCheckinDays(data);

    final weeklyReviews = _mapList(data['weekly_reviews']);

    weeklyReviews.sort(
      (a, b) => (a['week_end'] ?? '').toString().compareTo(
        (b['week_end'] ?? '').toString(),
      ),
    );

    final monthlyReviews = _mapList(data['monthly_reviews']);

    monthlyReviews.sort(
      (a, b) => (a['snapshot_date'] ?? '').toString().compareTo(
        (b['snapshot_date'] ?? '').toString(),
      ),
    );

    return {
      'recovery_insights_data': {
        'sobriety_date': sobrietyDate,
        'sobriety_days': sobrietyDays,
        'current_step': currentStep,
        'open_step_assignments': openAssignments,
        'active_recovery_goals': activeGoals,
        'checkin_days_available': checkinDays,
        'checkin_window_days': 7,
        'latest_weekly_snapshot': weeklyReviews.isEmpty
            ? null
            : weeklyReviews.last,
        'latest_monthly_snapshot': monthlyReviews.isEmpty
            ? null
            : monthlyReviews.last,
      },
    };
  }

  Future<Map<String, dynamic>> buildAiReflectionPayload() async {
    final result = await getInsights();

    final rawInsights = result['recovery_insights_data'];

    if (rawInsights is! Map) {
      return {'summary': ''};
    }

    final insights = Map<String, dynamic>.from(rawInsights);

    final sobrietyDays = insights['sobriety_days'];

    final sobrietyText = sobrietyDays is int ? '$sobrietyDays days' : 'not set';

    final currentStep = insights['current_step'] ?? 1;

    final openAssignments = insights['open_step_assignments'] ?? 0;

    final activeGoals = insights['active_recovery_goals'] ?? 0;

    final checkinDays = insights['checkin_days_available'] ?? 0;

    final checkinWindow = insights['checkin_window_days'] ?? 7;

    final lines = <String>[
      'Recovery Insights',
      '',
      'Sobriety: $sobrietyText',
      'Current Step: $currentStep',
      'Open Step assignments: $openAssignments',
      'Active recovery goals: $activeGoals',
      'Recent check-in days: '
          '$checkinDays of $checkinWindow',
    ];

    final weeklyRaw = insights['latest_weekly_snapshot'];

    if (weeklyRaw is Map) {
      final weekly = Map<String, dynamic>.from(weeklyRaw);

      lines.add('');
      lines.add('Latest weekly snapshot:');
      lines.add(
        'Period: '
        '${weekly['week_start'] ?? ''} '
        'through ${weekly['week_end'] ?? ''}',
      );
      lines.add(
        'Check-in days: '
        '${weekly['checkin_days'] ?? 0}',
      );
      lines.add(
        'Journal entries: '
        '${weekly['journal_entries'] ?? 0}',
      );
    }

    final monthlyRaw = insights['latest_monthly_snapshot'];

    if (monthlyRaw is Map) {
      final monthly = Map<String, dynamic>.from(monthlyRaw);

      lines.add('');
      lines.add('Latest monthly snapshot:');
      lines.add(
        'Period: '
        '${monthly['period_start'] ?? ''} '
        'through ${monthly['period_end'] ?? ''}',
      );
      lines.add(
        'Weekly reviews included: '
        '${monthly['weekly_reviews_included'] ?? 0}',
      );
      lines.add(
        'Check-in days: '
        '${monthly['checkin_days'] ?? 0}',
      );
      lines.add(
        'Journal entries: '
        '${monthly['journal_entries'] ?? 0}',
      );
    }

    return {'summary': lines.join('\n')};
  }

  int _recentCheckinDays(Map<String, dynamic> data) {
    final rawCheckins = data['daily_checkins'];

    if (rawCheckins is! Map) {
      return 0;
    }

    final checkins = Map<String, dynamic>.from(rawCheckins);

    final today = _dateOnly(_now());

    final start = today.subtract(const Duration(days: 6));

    var count = 0;

    for (final key in checkins.keys) {
      final parsed = DateTime.tryParse(key);

      if (parsed == null) {
        continue;
      }

      final date = _dateOnly(parsed);

      if (!date.isBefore(start) && !date.isAfter(today)) {
        count++;
      }
    }

    return count;
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
}
