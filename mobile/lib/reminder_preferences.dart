import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum NotificationPrivacyMode { private, descriptive }

class ReminderPreferences {
  const ReminderPreferences({
    required this.dailyRecoveryEnabled,
    required this.dailyRecoveryHour,
    required this.dailyRecoveryMinute,
    required this.weeklyReviewEnabled,
    required this.weeklyReviewWeekday,
    required this.weeklyReviewHour,
    required this.weeklyReviewMinute,
    required this.privacyMode,
  });

  static const int schemaVersion = 1;

  final bool dailyRecoveryEnabled;
  final int dailyRecoveryHour;
  final int dailyRecoveryMinute;

  final bool weeklyReviewEnabled;
  final int weeklyReviewWeekday;
  final int weeklyReviewHour;
  final int weeklyReviewMinute;

  final NotificationPrivacyMode privacyMode;

  factory ReminderPreferences.defaults() {
    return const ReminderPreferences(
      dailyRecoveryEnabled: false,
      dailyRecoveryHour: 8,
      dailyRecoveryMinute: 0,
      weeklyReviewEnabled: false,
      weeklyReviewWeekday: DateTime.sunday,
      weeklyReviewHour: 19,
      weeklyReviewMinute: 0,
      privacyMode: NotificationPrivacyMode.private,
    );
  }

  ReminderPreferences copyWith({
    bool? dailyRecoveryEnabled,
    int? dailyRecoveryHour,
    int? dailyRecoveryMinute,
    bool? weeklyReviewEnabled,
    int? weeklyReviewWeekday,
    int? weeklyReviewHour,
    int? weeklyReviewMinute,
    NotificationPrivacyMode? privacyMode,
  }) {
    return ReminderPreferences(
      dailyRecoveryEnabled: dailyRecoveryEnabled ?? this.dailyRecoveryEnabled,
      dailyRecoveryHour: dailyRecoveryHour ?? this.dailyRecoveryHour,
      dailyRecoveryMinute: dailyRecoveryMinute ?? this.dailyRecoveryMinute,
      weeklyReviewEnabled: weeklyReviewEnabled ?? this.weeklyReviewEnabled,
      weeklyReviewWeekday: weeklyReviewWeekday ?? this.weeklyReviewWeekday,
      weeklyReviewHour: weeklyReviewHour ?? this.weeklyReviewHour,
      weeklyReviewMinute: weeklyReviewMinute ?? this.weeklyReviewMinute,
      privacyMode: privacyMode ?? this.privacyMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'daily_recovery_enabled': dailyRecoveryEnabled,
      'daily_recovery_hour': dailyRecoveryHour,
      'daily_recovery_minute': dailyRecoveryMinute,
      'weekly_review_enabled': weeklyReviewEnabled,
      'weekly_review_weekday': weeklyReviewWeekday,
      'weekly_review_hour': weeklyReviewHour,
      'weekly_review_minute': weeklyReviewMinute,
      'privacy_mode': privacyMode.name,
    };
  }

  factory ReminderPreferences.fromJson(Map<String, dynamic> json) {
    final defaults = ReminderPreferences.defaults();

    return ReminderPreferences(
      dailyRecoveryEnabled: json['daily_recovery_enabled'] is bool
          ? json['daily_recovery_enabled'] as bool
          : defaults.dailyRecoveryEnabled,
      dailyRecoveryHour: _boundedInt(
        json['daily_recovery_hour'],
        minimum: 0,
        maximum: 23,
        fallback: defaults.dailyRecoveryHour,
      ),
      dailyRecoveryMinute: _boundedInt(
        json['daily_recovery_minute'],
        minimum: 0,
        maximum: 59,
        fallback: defaults.dailyRecoveryMinute,
      ),
      weeklyReviewEnabled: json['weekly_review_enabled'] is bool
          ? json['weekly_review_enabled'] as bool
          : defaults.weeklyReviewEnabled,
      weeklyReviewWeekday: _boundedInt(
        json['weekly_review_weekday'],
        minimum: DateTime.monday,
        maximum: DateTime.sunday,
        fallback: defaults.weeklyReviewWeekday,
      ),
      weeklyReviewHour: _boundedInt(
        json['weekly_review_hour'],
        minimum: 0,
        maximum: 23,
        fallback: defaults.weeklyReviewHour,
      ),
      weeklyReviewMinute: _boundedInt(
        json['weekly_review_minute'],
        minimum: 0,
        maximum: 59,
        fallback: defaults.weeklyReviewMinute,
      ),
      privacyMode: _privacyModeFrom(json['privacy_mode']),
    );
  }

  static int _boundedInt(
    dynamic value, {
    required int minimum,
    required int maximum,
    required int fallback,
  }) {
    if (value is! int || value < minimum || value > maximum) {
      return fallback;
    }

    return value;
  }

  static NotificationPrivacyMode _privacyModeFrom(dynamic value) {
    for (final mode in NotificationPrivacyMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }

    return NotificationPrivacyMode.private;
  }
}

abstract class ReminderPreferencesStorage {
  Future<String?> read();

  Future<void> write(String value);
}

class SharedPreferencesReminderStorage implements ReminderPreferencesStorage {
  SharedPreferencesReminderStorage({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String preferenceKey =
      'recovery_companion.reminder_preferences.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() {
    return _preferences.getString(preferenceKey);
  }

  @override
  Future<void> write(String value) async {
    await _preferences.setString(preferenceKey, value);
  }
}

class ReminderPreferencesRepository {
  ReminderPreferencesRepository({required this.storage});

  final ReminderPreferencesStorage storage;

  Future<ReminderPreferences> load() async {
    final encoded = await storage.read();

    if (encoded == null || encoded.isEmpty) {
      return ReminderPreferences.defaults();
    }

    try {
      final decoded = jsonDecode(encoded);

      if (decoded is! Map<String, dynamic>) {
        return ReminderPreferences.defaults();
      }

      return ReminderPreferences.fromJson(decoded);
    } catch (_) {
      return ReminderPreferences.defaults();
    }
  }

  Future<void> save(ReminderPreferences preferences) {
    return storage.write(jsonEncode(preferences.toJson()));
  }
}
