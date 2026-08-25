import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_preferences.dart';

enum ReminderKind { dailyRecovery, weeklyReview }

String reminderPayload(ReminderKind kind) {
  return switch (kind) {
    ReminderKind.dailyRecovery => 'daily_recovery',
    ReminderKind.weeklyReview => 'weekly_review',
  };
}

ReminderKind? reminderKindFromPayload(String? payload) {
  return switch (payload) {
    'daily_recovery' => ReminderKind.dailyRecovery,
    'weekly_review' => ReminderKind.weeklyReview,
    _ => null,
  };
}

class ReminderNotificationCopy {
  const ReminderNotificationCopy({required this.title, required this.body});

  final String title;
  final String body;
}

ReminderNotificationCopy reminderNotificationCopy({
  required ReminderKind kind,
  required NotificationPrivacyMode privacyMode,
}) {
  if (privacyMode == NotificationPrivacyMode.private) {
    return const ReminderNotificationCopy(
      title: 'Recovery Companion',
      body: 'A reminder you asked for is ready.',
    );
  }

  switch (kind) {
    case ReminderKind.dailyRecovery:
      return const ReminderNotificationCopy(
        title: 'Daily Recovery reminder',
        body:
            'Take a moment for the recovery '
            'practices you chose for today.',
      );

    case ReminderKind.weeklyReview:
      return const ReminderNotificationCopy(
        title: 'Weekly Review reminder',
        body:
            'Your weekly recovery reflection '
            'is ready when you are.',
      );
  }
}

DateTime nextDailyReminder({
  required DateTime now,
  required int hour,
  required int minute,
}) {
  var candidate = DateTime(now.year, now.month, now.day, hour, minute);

  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }

  return candidate;
}

DateTime nextWeeklyReminder({
  required DateTime now,
  required int weekday,
  required int hour,
  required int minute,
}) {
  final daysAhead = (weekday - now.weekday) % 7;

  var candidate = DateTime(
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  ).add(Duration(days: daysAhead));

  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 7));
  }

  return candidate;
}

abstract class ReminderSchedulingService {
  Future<bool> requestPermission();

  Future<void> apply(ReminderPreferences preferences);
}

class ReminderScheduler implements ReminderSchedulingService {
  ReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    this.onNotificationTap,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int dailyRecoveryNotificationId = 4901;

  static const int weeklyReviewNotificationId = 4902;

  static const String channelId = 'recovery_reminders';

  static const String channelName = 'Recovery reminders';

  static const String channelDescription =
      'Reminders the user chose in Recovery Companion.';

  final FlutterLocalNotificationsPlugin _plugin;
  final ValueChanged<String>? onNotificationTap;

  String? _launchPayload;

  bool _initialized = false;
  bool _supported = true;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _supported = switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      _ => false,
    };

    if (!_supported) {
      _initialized = true;
      return;
    }

    tz_data.initializeTimeZones();

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const apple = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: apple,
        macOS: apple,
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _launchPayload = launchDetails?.notificationResponse?.payload;
    }

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;

    if (reminderKindFromPayload(payload) == null) {
      return;
    }

    onNotificationTap?.call(payload!);
  }

  String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;

    if (reminderKindFromPayload(payload) == null) {
      return null;
    }

    return payload;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();

    if (!_supported) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;

      case TargetPlatform.iOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: false, sound: true) ??
            false;

      case TargetPlatform.macOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: false, sound: true) ??
            false;

      default:
        return false;
    }
  }

  @override
  Future<void> apply(ReminderPreferences preferences) async {
    await initialize();

    if (!_supported) {
      return;
    }

    await _plugin.cancel(id: dailyRecoveryNotificationId);

    await _plugin.cancel(id: weeklyReviewNotificationId);

    if (preferences.dailyRecoveryEnabled) {
      await _scheduleDaily(preferences);
    }

    if (preferences.weeklyReviewEnabled) {
      await _scheduleWeekly(preferences);
    }
  }

  Future<void> _scheduleDaily(ReminderPreferences preferences) async {
    final now = tz.TZDateTime.now(tz.local);

    final next = nextDailyReminder(
      now: now,
      hour: preferences.dailyRecoveryHour,
      minute: preferences.dailyRecoveryMinute,
    );

    final copy = reminderNotificationCopy(
      kind: ReminderKind.dailyRecovery,
      privacyMode: preferences.privacyMode,
    );

    await _plugin.zonedSchedule(
      id: dailyRecoveryNotificationId,
      title: copy.title,
      body: copy.body,
      scheduledDate: tz.TZDateTime(
        tz.local,
        next.year,
        next.month,
        next.day,
        next.hour,
        next.minute,
      ),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: reminderPayload(ReminderKind.dailyRecovery),
    );
  }

  Future<void> _scheduleWeekly(ReminderPreferences preferences) async {
    final now = tz.TZDateTime.now(tz.local);

    final next = nextWeeklyReminder(
      now: now,
      weekday: preferences.weeklyReviewWeekday,
      hour: preferences.weeklyReviewHour,
      minute: preferences.weeklyReviewMinute,
    );

    final copy = reminderNotificationCopy(
      kind: ReminderKind.weeklyReview,
      privacyMode: preferences.privacyMode,
    );

    await _plugin.zonedSchedule(
      id: weeklyReviewNotificationId,
      title: copy.title,
      body: copy.body,
      scheduledDate: tz.TZDateTime(
        tz.local,
        next.year,
        next.month,
        next.day,
        next.hour,
        next.minute,
      ),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: reminderPayload(ReminderKind.weeklyReview),
    );
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
  }
}
