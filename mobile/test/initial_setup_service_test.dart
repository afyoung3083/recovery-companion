import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/initial_setup_service.dart';
import 'package:mobile/local_goals_repository.dart';
import 'package:mobile/local_profile_repository.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/local_routines_repository.dart';
import 'package:mobile/reminder_preferences.dart';
import 'package:mobile/reminder_scheduler.dart';
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

class MemoryReminderStorage implements ReminderPreferencesStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class FakeReminderScheduler implements ReminderSchedulingService {
  bool permissionRequested = false;
  bool permissionGranted = true;
  ReminderPreferences? applied;

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return permissionGranted;
  }

  @override
  Future<void> apply(ReminderPreferences preferences) async {
    applied = preferences;
  }
}

void main() {
  late Directory directory;
  late LocalRecoveryStore store;
  late MemoryReminderStorage reminderStorage;
  late FakeReminderScheduler scheduler;
  late InitialSetupService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('initial_setup_test_');

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}'
        '${Platform.pathSeparator}'
        'recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    reminderStorage = MemoryReminderStorage();

    scheduler = FakeReminderScheduler();

    service = InitialSetupService(
      profileRepository: LocalProfileRepository(store: store),
      goalsRepository: LocalGoalsRepository(store: store),
      routinesRepository: LocalRoutinesRepository(store: store),
      reminderPreferencesRepository: ReminderPreferencesRepository(
        storage: reminderStorage,
      ),
      reminderScheduler: scheduler,
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('guided setup writes profile goal and routine locally', () async {
    await service.apply(
      const InitialSetupDraft(
        sobrietyDate: '2026-08-12',
        goalText: 'Stay connected today',
        routineText: 'Morning recovery reading',
      ),
    );

    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');

    expect(
      ((data['goals'] as List).first as Map)['text'],
      'Stay connected today',
    );

    expect(
      ((data['routines'] as List).first as Map)['text'],
      'Morning recovery reading',
    );
  });

  test('reminders remain disabled unless selected', () async {
    await service.apply(const InitialSetupDraft());

    final saved = await ReminderPreferencesRepository(storage: reminderStorage)
        .load();

    expect(saved.dailyRecoveryEnabled, isFalse);

    expect(saved.weeklyReviewEnabled, isFalse);

    expect(scheduler.permissionRequested, isFalse);
  });

  test(
    'selected reminders request permission and preserve privacy choice',
    () async {
      await service.apply(
        const InitialSetupDraft(
          dailyReminderEnabled: true,
          weeklyReminderEnabled: true,
          descriptiveNotifications: true,
        ),
      );

      expect(scheduler.permissionRequested, isTrue);

      expect(scheduler.applied?.dailyRecoveryEnabled, isTrue);

      expect(scheduler.applied?.weeklyReviewEnabled, isTrue);

      expect(
        scheduler.applied?.privacyMode,
        NotificationPrivacyMode.descriptive,
      );
    },
  );
}
