import 'package:flutter/material.dart';

import 'api_client.dart';

class DailyCheckInScreen extends StatefulWidget {
  const DailyCheckInScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends State<DailyCheckInScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _analyzing = false;

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

  Future<void> _loadToday() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.apiClient.getTodayCheckin();

      final checkin = result['checkin'];

      if (checkin is Map<String, dynamic>) {
        _prayerMeditation = checkin['prayer_meditation'] == true;
        _recoveryContact = checkin['recovery_contact'] == true;
        _meeting = checkin['meeting'] == true;
        _stepWork = checkin['step_work'] == true;
        _journal = checkin['journal'] == true;
        _service = checkin['service'] == true;

        _noteController.text = (
          checkin['note'] ??
          ''
        ).toString();
      }
    } catch (error) {
      _error = error.toString();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.apiClient.saveTodayCheckin(
        prayerMeditation: _prayerMeditation,
        recoveryContact: _recoveryContact,
        meeting: _meeting,
        stepWork: _stepWork,
        journal: _journal,
        service: _service,
        note: _noteController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Daily check-in saved.',
          ),
        ),
      );
    } catch (error) {
      _error = error.toString();
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
          title: const Text(
            'Analyze recent check-ins?',
          ),
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
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Analyze Check-Ins',
              ),
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
      final result =
          await widget.apiClient.analyzeRecentCheckins();

      if (!mounted) {
        return;
      }

      final reflection = (
        result['reflection'] ??
        ''
      ).toString().trim();

      final checkinCount = result['checkin_count'];

      setState(() {
        _aiCheckinCount = checkinCount is int
            ? checkinCount
            : null;

        _aiReflection = reflection.isEmpty
            ? 'No AI reflection was returned.'
            : reflection;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _aiError =
            'Unable to generate recent check-in reflection. '
            'Please try again.';
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
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Daily Recovery',
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Mark the recovery actions you completed today.',
        ),
        const SizedBox(height: 20),

        CheckboxListTile(
          value: _prayerMeditation,
          title: const Text(
            'Prayer / meditation',
          ),
          onChanged: (value) {
            setState(() {
              _prayerMeditation = value ?? false;
            });
          },
        ),

        CheckboxListTile(
          value: _recoveryContact,
          title: const Text(
            'Recovery contact',
          ),
          onChanged: (value) {
            setState(() {
              _recoveryContact = value ?? false;
            });
          },
        ),

        CheckboxListTile(
          value: _meeting,
          title: const Text(
            'Meeting',
          ),
          onChanged: (value) {
            setState(() {
              _meeting = value ?? false;
            });
          },
        ),

        CheckboxListTile(
          value: _stepWork,
          title: const Text(
            'Step work',
          ),
          onChanged: (value) {
            setState(() {
              _stepWork = value ?? false;
            });
          },
        ),

        CheckboxListTile(
          value: _journal,
          title: const Text(
            'Journal',
          ),
          onChanged: (value) {
            setState(() {
              _journal = value ?? false;
            });
          },
        ),

        CheckboxListTile(
          value: _service,
          title: const Text(
            'Service',
          ),
          onChanged: (value) {
            setState(() {
              _service = value ?? false;
            });
          },
        ),

        const SizedBox(height: 16),

        TextField(
          controller: _noteController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Daily note',
            border: OutlineInputBorder(),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .error,
            ),
          ),
        ],

        const SizedBox(height: 20),

        FilledButton.icon(
          onPressed: _saving
              ? null
              : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.save_outlined,
                ),
          label: Text(
            _saving
                ? 'Saving...'
                : 'Save Daily Check-In',
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton(
          onPressed: _loading
              ? null
              : _loadToday,
          child: const Text(
            'Reload Today',
          ),
        ),

        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 20),

        Text(
          'Recent Check-In AI Reflection',
          style: Theme.of(context)
              .textTheme
              .titleLarge,
        ),

        const SizedBox(height: 8),

        const Text(
          'AI reflection is optional. Only a summary of your most '
          'recent saved check-ins, up to seven, is sent to the AI, '
          'and only when you request it.',
        ),

        const SizedBox(height: 16),

        OutlinedButton.icon(
          key: const ValueKey(
            'daily-checkin-ai',
          ),
          onPressed: _analyzing
              ? null
              : _analyzeRecentCheckins,
          icon: _analyzing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.auto_awesome_outlined,
                ),
          label: Text(
            _analyzing
                ? 'Generating Reflection...'
                : 'Reflect on Recent Check-Ins',
          ),
        ),

        if (_aiError != null) ...[
          const SizedBox(height: 16),
          Text(
            _aiError!,
            key: const ValueKey(
              'daily-checkin-ai-error',
            ),
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .error,
            ),
          ),
        ],

        if (_aiReflection != null) ...[
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Reflection',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),

                  if (_aiCheckinCount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Based on $_aiCheckinCount recent '
                      'check-in${_aiCheckinCount == 1 ? '' : 's'}.',
                    ),
                  ],

                  const SizedBox(height: 12),

                  SelectableText(
                    _aiReflection!,
                    key: const ValueKey(
                      'daily-checkin-ai-reflection',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}