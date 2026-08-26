import 'package:flutter/material.dart';

import 'app_components.dart';
import 'reminder_preferences.dart';
import 'reminder_scheduler.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({this.repository, this.scheduler, super.key});

  final ReminderPreferencesRepository? repository;
  final ReminderSchedulingService? scheduler;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  static const _weekdays = <int, String>{
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  late final ReminderPreferencesRepository _repository;

  late final ReminderSchedulingService _scheduler;

  ReminderPreferences _preferences = ReminderPreferences.defaults();

  ReminderPreferences _savedPreferences = ReminderPreferences.defaults();

  bool _loading = true;
  bool _saving = false;

  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _repository =
        widget.repository ??
        ReminderPreferencesRepository(
          storage: SharedPreferencesReminderStorage(),
        );

    _scheduler = widget.scheduler ?? ReminderScheduler();

    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await _repository.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = loaded;
        _savedPreferences = loaded;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage =
            'Unable to load reminder settings. '
            'No reminder settings were changed.';
      });
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      final anyEnabled =
          _preferences.dailyRecoveryEnabled || _preferences.weeklyReviewEnabled;

      if (anyEnabled) {
        final granted = await _scheduler.requestPermission();

        if (!granted) {
          if (!mounted) {
            return;
          }

          setState(() {
            _preferences = _savedPreferences;
            _errorMessage =
                'Notifications are not enabled for '
                'Recovery Companion. Your saved reminder '
                'settings were not changed.';
          });

          return;
        }
      }

      await _scheduler.apply(_preferences);
      await _repository.save(_preferences);

      if (!mounted) {
        return;
      }

      setState(() {
        _savedPreferences = _preferences;

        _statusMessage = anyEnabled
            ? 'Reminder settings saved on this device.'
            : 'Reminders are turned off on this device.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _preferences = _savedPreferences;

        _errorMessage =
            'Unable to update reminders. '
            'Your saved reminder settings were not '
            'intentionally changed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _pickDailyTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _preferences.dailyRecoveryHour,
        minute: _preferences.dailyRecoveryMinute,
      ),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _preferences = _preferences.copyWith(
        dailyRecoveryHour: picked.hour,
        dailyRecoveryMinute: picked.minute,
      );

      _clearMessages();
    });
  }

  Future<void> _pickWeeklyTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _preferences.weeklyReviewHour,
        minute: _preferences.weeklyReviewMinute,
      ),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _preferences = _preferences.copyWith(
        weeklyReviewHour: picked.hour,
        weeklyReviewMinute: picked.minute,
      );

      _clearMessages();
    });
  }

  void _clearMessages() {
    _statusMessage = null;
    _errorMessage = null;
  }

  String _formatTime(BuildContext context, int hour, int minute) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final descriptive =
        _preferences.privacyMode == NotificationPrivacyMode.descriptive;

    final preview = reminderNotificationCopy(
      kind: ReminderKind.dailyRecovery,
      privacyMode: _preferences.privacyMode,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppPageHeader(
          title: 'Reminders',
          subtitle:
              'Choose optional reminders that are '
              'scheduled on this device.',
          icon: Icons.notifications_active_outlined,
        ),

        if (_statusMessage != null) ...[
          AppStatusMessage(
            title: _statusMessage!,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 20),
        ],

        if (_errorMessage != null) ...[
          AppStatusMessage(
            title: 'Reminder settings unchanged',
            message: _errorMessage,
            icon: Icons.notifications_off_outlined,
          ),
          const SizedBox(height: 20),
        ],

        const AppSectionTitle(
          title: 'Daily Recovery',
          subtitle:
              'A gentle prompt for the recovery '
              'practices you chose for today.',
        ),

        AppSectionCard(
          child: Column(
            children: [
              SwitchListTile(
                key: const ValueKey('daily-reminder-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily reminder'),
                subtitle: const Text(
                  'Off by default. Turn it on only '
                  'if you want a daily notification.',
                ),
                value: _preferences.dailyRecoveryEnabled,
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(
                            dailyRecoveryEnabled: value,
                          );

                          _clearMessages();
                        });
                      },
              ),
              const Divider(),
              ListTile(
                key: const ValueKey('daily-reminder-time'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Reminder time'),
                subtitle: Text(
                  _formatTime(
                    context,
                    _preferences.dailyRecoveryHour,
                    _preferences.dailyRecoveryMinute,
                  ),
                ),
                trailing: const Icon(Icons.edit_outlined),
                enabled: _preferences.dailyRecoveryEnabled && !_saving,
                onTap: _pickDailyTime,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Weekly Review',
          subtitle:
              'Choose when you want a prompt to '
              'pause and look back at the week.',
        ),

        AppSectionCard(
          child: Column(
            children: [
              SwitchListTile(
                key: const ValueKey('weekly-reminder-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Weekly reminder'),
                subtitle: const Text(
                  'A reminder is not a judgment if '
                  'you choose not to act on it.',
                ),
                value: _preferences.weeklyReviewEnabled,
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(
                            weeklyReviewEnabled: value,
                          );

                          _clearMessages();
                        });
                      },
              ),
              const Divider(),
              DropdownButtonFormField<int>(
                key: const ValueKey('weekly-reminder-day'),
                initialValue: _preferences.weeklyReviewWeekday,
                decoration: const InputDecoration(labelText: 'Day'),
                items: _weekdays.entries
                    .map(
                      (entry) => DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: !_preferences.weeklyReviewEnabled || _saving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _preferences = _preferences.copyWith(
                            weeklyReviewWeekday: value,
                          );

                          _clearMessages();
                        });
                      },
              ),
              const SizedBox(height: 8),
              ListTile(
                key: const ValueKey('weekly-reminder-time'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Reminder time'),
                subtitle: Text(
                  _formatTime(
                    context,
                    _preferences.weeklyReviewHour,
                    _preferences.weeklyReviewMinute,
                  ),
                ),
                trailing: const Icon(Icons.edit_outlined),
                enabled: _preferences.weeklyReviewEnabled && !_saving,
                onTap: _pickWeeklyTime,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Notification privacy',
          subtitle:
              'Choose what can appear on your '
              'lock screen.',
        ),

        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                key: const ValueKey('descriptive-notification-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Show recovery details'),
                subtitle: const Text(
                  'Keep this off for generic '
                  'notification wording.',
                ),
                value: descriptive,
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _preferences = _preferences.copyWith(
                            privacyMode: value
                                ? NotificationPrivacyMode.descriptive
                                : NotificationPrivacyMode.private,
                          );

                          _clearMessages();
                        });
                      },
              ),
              const Divider(),
              Text(
                'Notification preview',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                preview.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(preview.body),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('save-reminders'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save Reminder Settings'),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Recovery Companion asks for system '
          'notification permission only when you '
          'save at least one enabled reminder.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
