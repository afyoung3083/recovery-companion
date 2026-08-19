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
  String? _error;

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
      ],
    );
  }
}