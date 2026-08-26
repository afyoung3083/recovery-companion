import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/reminder_preferences.dart';

class FakeReminderStorage implements ReminderPreferencesStorage {
  String? value;

  @override
  Future<String?> read() async {
    return value;
  }

  @override
  Future<void> write(String newValue) async {
    value = newValue;
  }
}

void main() {
  test('Reminder defaults are disabled and privacy-first', () {
    final preferences = ReminderPreferences.defaults();

    expect(preferences.dailyRecoveryEnabled, false);
    expect(preferences.weeklyReviewEnabled, false);
    expect(preferences.dailyRecoveryHour, 8);
    expect(preferences.weeklyReviewWeekday, DateTime.sunday);
    expect(preferences.weeklyReviewHour, 19);
    expect(preferences.privacyMode, NotificationPrivacyMode.private);
  });

  test('Reminder preferences round-trip through JSON', () {
    final original = ReminderPreferences.defaults().copyWith(
      dailyRecoveryEnabled: true,
      dailyRecoveryHour: 6,
      dailyRecoveryMinute: 30,
      weeklyReviewEnabled: true,
      weeklyReviewWeekday: DateTime.friday,
      weeklyReviewHour: 20,
      weeklyReviewMinute: 15,
      privacyMode: NotificationPrivacyMode.descriptive,
    );

    final restored = ReminderPreferences.fromJson(original.toJson());

    expect(restored.dailyRecoveryEnabled, true);
    expect(restored.dailyRecoveryHour, 6);
    expect(restored.dailyRecoveryMinute, 30);
    expect(restored.weeklyReviewEnabled, true);
    expect(restored.weeklyReviewWeekday, DateTime.friday);
    expect(restored.weeklyReviewHour, 20);
    expect(restored.weeklyReviewMinute, 15);
    expect(restored.privacyMode, NotificationPrivacyMode.descriptive);
  });

  test('Invalid stored values fall back safely', () {
    final restored = ReminderPreferences.fromJson({
      'daily_recovery_enabled': true,
      'daily_recovery_hour': 99,
      'daily_recovery_minute': -1,
      'weekly_review_weekday': 10,
      'weekly_review_hour': 44,
      'privacy_mode': 'unknown',
    });

    expect(restored.dailyRecoveryEnabled, true);
    expect(restored.dailyRecoveryHour, 8);
    expect(restored.dailyRecoveryMinute, 0);
    expect(restored.weeklyReviewWeekday, DateTime.sunday);
    expect(restored.weeklyReviewHour, 19);
    expect(restored.privacyMode, NotificationPrivacyMode.private);
  });

  test('Repository returns defaults for missing or corrupt data', () async {
    final storage = FakeReminderStorage();

    final repository = ReminderPreferencesRepository(storage: storage);

    var loaded = await repository.load();

    expect(loaded.dailyRecoveryEnabled, false);

    storage.value = '{not valid json';

    loaded = await repository.load();

    expect(loaded.privacyMode, NotificationPrivacyMode.private);
  });

  test('Repository saves and reloads reminder preferences', () async {
    final storage = FakeReminderStorage();

    final repository = ReminderPreferencesRepository(storage: storage);

    final preferences = ReminderPreferences.defaults().copyWith(
      dailyRecoveryEnabled: true,
      dailyRecoveryHour: 7,
      privacyMode: NotificationPrivacyMode.descriptive,
    );

    await repository.save(preferences);

    final storedJson = jsonDecode(storage.value!) as Map<String, dynamic>;

    expect(storedJson['schema_version'], 1);

    final loaded = await repository.load();

    expect(loaded.dailyRecoveryEnabled, true);
    expect(loaded.dailyRecoveryHour, 7);
    expect(loaded.privacyMode, NotificationPrivacyMode.descriptive);
  });
}
