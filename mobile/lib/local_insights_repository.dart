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
