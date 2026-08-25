import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/reminder_preferences.dart';
import 'package:mobile/reminder_scheduler.dart';

void main() {
  test('Private reminder copy reveals no recovery detail', () {
    final daily = reminderNotificationCopy(
      kind: ReminderKind.dailyRecovery,
      privacyMode: NotificationPrivacyMode.private,
    );

    final weekly = reminderNotificationCopy(
      kind: ReminderKind.weeklyReview,
      privacyMode: NotificationPrivacyMode.private,
    );

    expect(daily.title, 'Recovery Companion');
    expect(daily.body, 'A reminder you asked for is ready.');

    expect(weekly.title, daily.title);
    expect(weekly.body, daily.body);

    expect(daily.body.toLowerCase(), isNot(contains('recovery')));
    expect(weekly.body.toLowerCase(), isNot(contains('weekly')));
  });

  test('Descriptive reminder copy stays supportive', () {
    final daily = reminderNotificationCopy(
      kind: ReminderKind.dailyRecovery,
      privacyMode: NotificationPrivacyMode.descriptive,
    );

    final weekly = reminderNotificationCopy(
      kind: ReminderKind.weeklyReview,
      privacyMode: NotificationPrivacyMode.descriptive,
    );

    expect(daily.title, 'Daily Recovery reminder');
    expect(weekly.title, 'Weekly Review reminder');

    expect(weekly.body, contains('ready when you are'));

    expect(daily.body.toLowerCase(), isNot(contains('missed')));
    expect(weekly.body.toLowerCase(), isNot(contains('failed')));
  });

  test('Daily reminder rolls to tomorrow after time passes', () {
    final now = DateTime(2026, 8, 25, 9, 0);

    final next = nextDailyReminder(now: now, hour: 8, minute: 0);

    expect(next, DateTime(2026, 8, 26, 8, 0));
  });

  test('Weekly reminder uses next matching weekday', () {
    final now = DateTime(2026, 8, 25, 12, 0);

    final next = nextWeeklyReminder(
      now: now,
      weekday: DateTime.sunday,
      hour: 19,
      minute: 0,
    );

    expect(next, DateTime(2026, 8, 30, 19, 0));
  });

  test('Weekly reminder rolls one week if todays time passed', () {
    final now = DateTime(2026, 8, 30, 20, 0);

    final next = nextWeeklyReminder(
      now: now,
      weekday: DateTime.sunday,
      hour: 19,
      minute: 0,
    );

    expect(next, DateTime(2026, 9, 6, 19, 0));
  });
  test('Reminder payloads map to their recovery destinations', () {
    expect(
      reminderKindFromPayload('daily_recovery'),
      ReminderKind.dailyRecovery,
    );

    expect(reminderKindFromPayload('weekly_review'), ReminderKind.weeklyReview);
  });

  test('Unknown notification payload is ignored', () {
    expect(reminderKindFromPayload('unknown'), isNull);

    expect(reminderKindFromPayload(null), isNull);
  });
}
