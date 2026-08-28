import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'offline_copy_notice.dart';
import 'offline_read_service.dart';
import 'local_daily_checkin_repository.dart';

class DailyCheckInScreen extends StatefulWidget {
  const DailyCheckInScreen({
    required this.apiClient,
    this.offlineReadService,
    this.localRepository,
    this.now,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineReadService? offlineReadService;
  final LocalDailyCheckInRepository? localRepository;
  final DateTime Function()? now;

  @override
  State<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends State<DailyCheckInScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _analyzing = false;

  OfflineReadResult? _readResult;

  String? _error;
  String? _aiError;
  String? _aiReflection;
  int? _aiCheckinCount;

  bool _prayerMeditation = false;
  bool _recoveryContact = false;
  bool _meeting = false;
  bool _stepWork = false;
  bool _journal = false;
  bool _service = false;

  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  DateTime _now() {
    return widget.now?.call() ?? DateTime.now();
  }

  Future<OfflineReadResult> _readToday() async {
    final localRepository = widget.localRepository;

    if (localRepository != null) {
      final data = await localRepository.getToday();

      return OfflineReadResult(data: data, source: OfflineReadSource.network);
    }

    final service = widget.offlineReadService;

    if (service == null) {
      final data = await widget.apiClient.getTodayCheckin();

      return OfflineReadResult(data: data, source: OfflineReadSource.network);
    }

    return service.read(
      cacheKey: OfflineCacheKeys.dailyCheckin(_now()),
      networkRead: widget.apiClient.getTodayCheckin,
    );
  }

  Future<void> _loadToday() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final readResult = await _readToday();
      final checkin = readResult.data['checkin'];

      if (!mounted) {
        return;
      }

      setState(() {
        _readResult = readResult;

        if (checkin is Map<String, dynamic>) {
          _prayerMeditation = checkin['prayer_meditation'] == true;
          _recoveryContact = checkin['recovery_contact'] == true;
          _meeting = checkin['meeting'] == true;
          _stepWork = checkin['step_work'] == true;
          _journal = checkin['journal'] == true;
          _service = checkin['service'] == true;

          _noteController.text = (checkin['note'] ?? '').toString();
        } else {
          _prayerMeditation = false;
          _recoveryContact = false;
          _meeting = false;
          _stepWork = false;
          _journal = false;
          _service = false;
          _noteController.clear();
        }

        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _readResult = null;
        _loading = false;
        _error =
            'Unable to load today\'s check-in. '
            'Please try again.';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.saveToday(
          prayerMeditation: _prayerMeditation,
          recoveryContact: _recoveryContact,
          meeting: _meeting,
          stepWork: _stepWork,
          journal: _journal,
          service: _service,
          note: _noteController.text.trim(),
        );
      } else {
        await widget.apiClient.saveTodayCheckin(
          prayerMeditation: _prayerMeditation,
          recoveryContact: _recoveryContact,
          meeting: _meeting,
          stepWork: _stepWork,
          journal: _journal,
          service: _service,
          note: _noteController.text.trim(),
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Daily check-in saved.')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to save today\'s check-in. Please try again.';
        });
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
  }

  Future<void> _analyzeRecentCheckins() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Analyze recent check-ins?'),
          content: const Text(
            'Recovery Companion will create a summary of your most '
            'recent saved check-ins, up to seven, and send only that '
            'summary to the AI for an optional recovery reflection. '
            'The reflection is not saved automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Analyze Check-Ins'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _analyzing = true;
      _aiError = null;
      _aiReflection = null;
      _aiCheckinCount = null;
    });

    try {
      final localRepository = widget.localRepository;

      late final Map<String, dynamic> result;

      if (localRepository != null) {
        final payload = await localRepository.buildAiReflectionPayload();

        final summary = (payload['summary'] ?? '').toString().trim();

        final checkinCount = payload['checkin_count'] is int
            ? payload['checkin_count'] as int
            : 0;

        if (summary.isEmpty || checkinCount == 0) {
          throw StateError('No recent local check-ins are available.');
        }

        result = await widget.apiClient.analyzeRecentCheckins(
          summary: summary,
          checkinCount: checkinCount,
        );
      } else {
        result = await widget.apiClient.analyzeRecentCheckins();
      }

      if (!mounted) {
        return;
      }

      final reflection = (result['reflection'] ?? '').toString().trim();

      final checkinCount = result['checkin_count'];

      setState(() {
        _aiCheckinCount = checkinCount is int ? checkinCount : null;

        _aiReflection = reflection.isEmpty
            ? 'No AI reflection was returned.'
            : reflection;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _aiError = 'Unable to generate a recent check-in reflection. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _analyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppPageHeader(
          title: 'Daily Recovery',
          subtitle: 'Notice the recovery practices that were part of your day.',
          icon: Icons.today_outlined,
        ),

        if (_readResult?.isCached == true) ...[
          OfflineCopyNotice(
            cachedAt: _readResult?.cachedAt,
            onRetry: _loadToday,
            detail: 'AI reflection still requires a connection.',
          ),
          const SizedBox(height: 20),
        ],

        if (_error != null) ...[
          AppStatusMessage(
            title: 'Daily check-in unavailable',
            message: _error!,
            icon: Icons.error_outline,
            actionLabel: 'Reload',
            onAction: _loadToday,
          ),
          const SizedBox(height: 24),
        ],

        const AppSectionTitle(
          title: 'Today',
          subtitle:
              'Mark what was present today. This is awareness, not a score.',
        ),

        AppSectionCard(
          key: const ValueKey('daily-recovery-actions-card'),
          child: Column(
            children: [
              _RecoveryActionTile(
                key: const ValueKey('daily-action-prayer'),
                icon: Icons.self_improvement_outlined,
                title: 'Prayer / meditation',
                subtitle:
                    'Time set aside for prayer, meditation, or stillness.',
                value: _prayerMeditation,
                onChanged: (value) {
                  setState(() {
                    _prayerMeditation = value;
                  });
                },
              ),
              const Divider(height: 1),
              _RecoveryActionTile(
                key: const ValueKey('daily-action-contact'),
                icon: Icons.people_outline,
                title: 'Recovery contact',
                subtitle:
                    'Sponsor, fellow traveler, or another recovery connection.',
                value: _recoveryContact,
                onChanged: (value) {
                  setState(() {
                    _recoveryContact = value;
                  });
                },
              ),
              const Divider(height: 1),
              _RecoveryActionTile(
                key: const ValueKey('daily-action-meeting'),
                icon: Icons.groups_outlined,
                title: 'Meeting',
                subtitle: 'Participated in a recovery meeting or group.',
                value: _meeting,
                onChanged: (value) {
                  setState(() {
                    _meeting = value;
                  });
                },
              ),
              const Divider(height: 1),
              _RecoveryActionTile(
                key: const ValueKey('daily-action-step-work'),
                icon: Icons.format_list_numbered,
                title: 'Step work',
                subtitle: 'Spent time on current Step work or an assignment.',
                value: _stepWork,
                onChanged: (value) {
                  setState(() {
                    _stepWork = value;
                  });
                },
              ),
              const Divider(height: 1),
              _RecoveryActionTile(
                key: const ValueKey('daily-action-journal'),
                icon: Icons.menu_book_outlined,
                title: 'Journal',
                subtitle: 'Wrote or reflected in your recovery journal.',
                value: _journal,
                onChanged: (value) {
                  setState(() {
                    _journal = value;
                  });
                },
              ),
              const Divider(height: 1),
              _RecoveryActionTile(
                key: const ValueKey('daily-action-service'),
                icon: Icons.volunteer_activism_outlined,
                title: 'Service',
                subtitle: 'Helped another person or contributed in service.',
                value: _service,
                onChanged: (value) {
                  setState(() {
                    _service = value;
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Daily Note',
          subtitle: 'Optional context you want to remember about today.',
        ),

        AppSectionCard(
          child: TextField(
            controller: _noteController,
            maxLines: 4,
            minLines: 3,
            decoration: const InputDecoration(
              labelText: 'What stands out today?',
              hintText: 'A thought, gratitude, struggle, connection, or next right thing...',
              prefixIcon: Icon(Icons.edit_note_outlined),
              alignLabelWithHint: true,
            ),
          ),
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('daily-checkin-save'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_outlined),
            label: Text(_saving ? 'Saving...' : 'Save Today'),
          ),
        ),

        const SizedBox(height: 8),

        TextButton.icon(
          onPressed: _loading ? null : _loadToday,
          icon: const Icon(Icons.refresh),
          label: const Text('Reload Today'),
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Recent Reflection',
          subtitle:
              'Optional AI perspective on patterns across recent check-ins.',
        ),

        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Only a locally built summary of up to seven recent saved check-ins is sent, and only after you confirm. The AI reflection is not saved automatically.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('daily-checkin-ai'),
                  onPressed: _analyzing || _readResult?.isCached == true
                      ? null
                      : _analyzeRecentCheckins,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    _analyzing
                        ? 'Generating Reflection...'
                        : 'Reflect on Recent Check-Ins',
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_aiError != null) ...[
          const SizedBox(height: 16),
          AppStatusMessage(
            title: 'Reflection unavailable',
            message: _aiError!,
            icon: Icons.error_outline,
          ),
        ],

        if (_aiReflection != null) ...[
          const SizedBox(height: 16),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recovery Companion Reflection',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (_aiCheckinCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Based on $_aiCheckinCount recent '
                    'check-in${_aiCheckinCount == 1 ? '' : 's'}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                SelectableText(
                  _aiReflection!,
                  key: const ValueKey('daily-checkin-ai-reflection'),
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RecoveryActionTile extends StatelessWidget {
  const _RecoveryActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        onChanged(!value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 21,
                color: value
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Checkbox(
              value: value,
              onChanged: (next) {
                onChanged(next ?? false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
