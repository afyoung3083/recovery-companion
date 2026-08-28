import 'local_recovery_store.dart';

class LocalDailyCheckInRepository {
  LocalDailyCheckInRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LocalRecoveryStore store;
  final DateTime Function() _now;

  Future<Map<String, dynamic>> getToday() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final dailyCheckinsRaw = data['daily_checkins'];
    final dailyCheckins = dailyCheckinsRaw is Map
        ? Map<String, dynamic>.from(dailyCheckinsRaw)
        : <String, dynamic>{};

    final key = _dateKey(_now());
    final checkinRaw = dailyCheckins[key];

    return {
      'checkin': checkinRaw is Map
          ? Map<String, dynamic>.from(checkinRaw)
          : null,
    };
  }

  Future<Map<String, dynamic>> saveToday({
    required bool prayerMeditation,
    required bool recoveryContact,
    required bool meeting,
    required bool stepWork,
    required bool journal,
    required bool service,
    required String note,
  }) async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final dailyCheckinsRaw = data['daily_checkins'];
    final dailyCheckins = dailyCheckinsRaw is Map
        ? Map<String, dynamic>.from(dailyCheckinsRaw)
        : <String, dynamic>{};

    final key = _dateKey(_now());

    final checkin = {
      'date': key,
      'prayer_meditation': prayerMeditation,
      'recovery_contact': recoveryContact,
      'meeting': meeting,
      'step_work': stepWork,
      'journal': journal,
      'service': service,
      'note': note,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    dailyCheckins[key] = checkin;
    data['daily_checkins'] = dailyCheckins;

    await store.write(data);

    return {'checkin': checkin};
  }

  Future<Map<String, dynamic>> buildAiReflectionPayload() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final rawCheckins = data['daily_checkins'];

    if (rawCheckins is! Map) {
      return {'summary': '', 'checkin_count': 0};
    }

    final checkins = rawCheckins.entries
        .where((entry) => entry.value is Map)
        .map(
          (entry) => {
            'date': entry.key.toString(),
            ...Map<String, dynamic>.from(entry.value as Map),
          },
        )
        .toList();

    checkins.sort(
      (a, b) =>
          (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()),
    );

    final recent = checkins.take(7).toList();

    if (recent.isEmpty) {
      return {'summary': '', 'checkin_count': 0};
    }

    const fields = <String, String>{
      'prayer_meditation': 'Prayer / meditation',
      'recovery_contact': 'Recovery contact',
      'meeting': 'Meeting',
      'step_work': 'Step work',
      'journal': 'Journal',
      'service': 'Service',
    };

    final historyLines = <String>[];

    for (final checkin in recent) {
      final completed = fields.keys
          .where((field) => checkin[field] == true)
          .length;

      historyLines.add(
        '${checkin['date']}: '
        '$completed/${fields.length} completed',
      );

      final note = (checkin['note'] ?? '').toString().trim();

      if (note.isNotEmpty) {
        historyLines.add('  Note: $note');
      }
    }

    final totals = <String, int>{for (final field in fields.keys) field: 0};

    for (final checkin in recent) {
      for (final field in fields.keys) {
        if (checkin[field] == true) {
          totals[field] = totals[field]! + 1;
        }
      }
    }

    final trendLines = <String>['Across ${recent.length} recent check-ins:'];

    for (final entry in fields.entries) {
      trendLines.add(
        '${entry.value}: '
        '${totals[entry.key]}/${recent.length}',
      );
    }

    return {
      'summary':
          '${historyLines.join('\n')}\n\n'
          '${trendLines.join('\n')}',
      'checkin_count': recent.length,
    };
  }

  String _dateKey(DateTime value) {
    final local = value.toLocal();

    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
