import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_daily_checkin_repository.dart';
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
  late Directory tempDirectory;
  late LocalRecoveryStore store;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'daily_checkin_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${tempDirectory.path}${Platform.pathSeparator}recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('returns no checkin when today has not been saved', () async {
    final repository = LocalDailyCheckInRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 9),
    );

    final result = await repository.getToday();

    expect(result['checkin'], isNull);
  });

  test('saves and reloads today checkin locally', () async {
    final repository = LocalDailyCheckInRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 9),
    );

    await repository.saveToday(
      prayerMeditation: true,
      recoveryContact: true,
      meeting: false,
      stepWork: true,
      journal: true,
      service: false,
      note: 'Stayed connected today.',
    );

    final result = await repository.getToday();

    final checkin = Map<String, dynamic>.from(result['checkin'] as Map);

    expect(checkin['date'], '2026-08-27');
    expect(checkin['prayer_meditation'], isTrue);
    expect(checkin['recovery_contact'], isTrue);
    expect(checkin['meeting'], isFalse);
    expect(checkin['step_work'], isTrue);
    expect(checkin['journal'], isTrue);
    expect(checkin['service'], isFalse);
    expect(checkin['note'], 'Stayed connected today.');
  });

  test('does not return yesterday as today', () async {
    final yesterdayRepository = LocalDailyCheckInRepository(
      store: store,
      now: () => DateTime(2026, 8, 26, 21),
    );

    await yesterdayRepository.saveToday(
      prayerMeditation: true,
      recoveryContact: false,
      meeting: true,
      stepWork: false,
      journal: false,
      service: false,
      note: 'Yesterday',
    );

    final todayRepository = LocalDailyCheckInRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 8),
    );

    final result = await todayRepository.getToday();

    expect(result['checkin'], isNull);
  });

  test('saving today preserves other recovery data', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'journal': [
        {'text': 'Keep this journal entry'},
      ],
    });

    final repository = LocalDailyCheckInRepository(
      store: store,
      now: () => DateTime(2026, 8, 27),
    );

    await repository.saveToday(
      prayerMeditation: true,
      recoveryContact: true,
      meeting: true,
      stepWork: true,
      journal: true,
      service: true,
      note: '',
    );

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');

    expect(
      ((data['journal'] as List).first as Map)['text'],
      'Keep this journal entry',
    );

    expect(data['daily_checkins'], isA<Map>());
  });

  test('saving same day updates instead of duplicating', () async {
    final repository = LocalDailyCheckInRepository(
      store: store,
      now: () => DateTime(2026, 8, 27),
    );

    await repository.saveToday(
      prayerMeditation: false,
      recoveryContact: false,
      meeting: false,
      stepWork: false,
      journal: false,
      service: false,
      note: 'First',
    );

    await repository.saveToday(
      prayerMeditation: true,
      recoveryContact: true,
      meeting: true,
      stepWork: true,
      journal: true,
      service: true,
      note: 'Updated',
    );

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final checkins = Map<String, dynamic>.from(data['daily_checkins'] as Map);

    expect(checkins.length, 1);

    final checkin = Map<String, dynamic>.from(checkins['2026-08-27'] as Map);

    expect(checkin['note'], 'Updated');
    expect(checkin['meeting'], isTrue);
  });
}
