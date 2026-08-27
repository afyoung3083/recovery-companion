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

  String _dateKey(DateTime value) {
    final local = value.toLocal();

    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
