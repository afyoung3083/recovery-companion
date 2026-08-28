import 'package:flutter/material.dart';

import 'initial_setup_service.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({
    required this.onFinish,
    required this.onSkip,
    super.key,
  });

  final Future<void> Function(InitialSetupDraft draft) onFinish;

  final Future<void> Function() onSkip;

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final PageController _controller = PageController();

  final TextEditingController _sobrietyDateController = TextEditingController();

  final TextEditingController _goalController = TextEditingController();

  final TextEditingController _routineController = TextEditingController();

  int _page = 0;
  bool _busy = false;

  bool _dailyReminder = false;
  bool _weeklyReminder = false;
  bool _descriptiveNotifications = false;

  static const int _pageCount = 4;

  Future<void> _pickSobrietyDate() async {
    final now = DateTime.now();

    final initial =
        DateTime.tryParse(_sobrietyDateController.text.trim()) ?? now;

    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (selected == null) {
      return;
    }

    _sobrietyDateController.text = _dateKey(selected);
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Future<void> _next() async {
    if (_page < _pageCount - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await widget.onFinish(
        InitialSetupDraft(
          sobrietyDate: _sobrietyDateController.text,
          goalText: _goalController.text,
          routineText: _routineController.text,
          dailyReminderEnabled: _dailyReminder,
          weeklyReminderEnabled: _weeklyReminder,
          descriptiveNotifications: _descriptiveNotifications,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _skip() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await widget.onSkip();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _sobrietyDateController.dispose();
    _goalController.dispose();
    _routineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      key: const ValueKey('initial-setup-screen'),
      appBar: AppBar(
        title: const Text('Optional setup'),
        actions: [
          TextButton(
            key: const ValueKey('initial-setup-skip'),
            onPressed: _busy ? null : _skip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (value) {
                  setState(() {
                    _page = value;
                  });
                },
                children: [
                  _SobrietyDatePage(
                    controller: _sobrietyDateController,
                    onPick: _pickSobrietyDate,
                  ),
                  _TextSetupPage(
                    icon: Icons.flag_outlined,
                    title: 'What are you working toward?',
                    body: 'Add one recovery goal if something important is already clear. You can add or change goals later.',
                    fieldLabel: 'First recovery goal',
                    hint: 'Example: Call my sponsor before isolating',
                    controller: _goalController,
                    fieldKey: const ValueKey('initial-goal-field'),
                  ),
                  _TextSetupPage(
                    icon: Icons.repeat_outlined,
                    title: 'What will you practice daily?',
                    body: 'A routine is a small recovery action you want to repeat consistently.',
                    fieldLabel: 'First daily routine',
                    hint: 'Example: Morning prayer and meditation',
                    controller: _routineController,
                    fieldKey: const ValueKey('initial-routine-field'),
                  ),
                  _ReminderSetupPage(
                    dailyEnabled: _dailyReminder,
                    weeklyEnabled: _weeklyReminder,
                    descriptive: _descriptiveNotifications,
                    onDailyChanged: (value) {
                      setState(() {
                        _dailyReminder = value;
                      });
                    },
                    onWeeklyChanged: (value) {
                      setState(() {
                        _weeklyReminder = value;
                      });
                    },
                    onDescriptiveChanged: (value) {
                      setState(() {
                        _descriptiveNotifications = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  Text('${_page + 1} of $_pageCount'),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('initial-setup-next'),
                      onPressed: _busy ? null : _next,
                      icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
                      label: Text(
                        _busy
                            ? 'Saving...'
                            : isLast
                            ? 'Finish setup'
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SobrietyDatePage extends StatelessWidget {
  const _SobrietyDatePage({required this.controller, required this.onPick});

  final TextEditingController controller;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return _SetupPageFrame(
      icon: Icons.calendar_today_outlined,
      title: 'Would you like to track a sobriety date?',
      body: 'This is optional. If you use a sobriety date, it can help the app calculate milestones and provide context for your recovery dashboard.',
      child: TextField(
        key: const ValueKey('initial-sobriety-date-field'),
        controller: controller,
        readOnly: true,
        onTap: onPick,
        decoration: const InputDecoration(
          labelText: 'Sobriety date',
          hintText: 'YYYY-MM-DD',
          suffixIcon: Icon(Icons.calendar_month),
        ),
      ),
    );
  }
}

class _TextSetupPage extends StatelessWidget {
  const _TextSetupPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.fieldLabel,
    required this.hint,
    required this.controller,
    required this.fieldKey,
  });

  final IconData icon;
  final String title;
  final String body;
  final String fieldLabel;
  final String hint;
  final TextEditingController controller;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) {
    return _SetupPageFrame(
      icon: icon,
      title: title,
      body: body,
      child: TextField(
        key: fieldKey,
        controller: controller,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: fieldLabel, hintText: hint),
      ),
    );
  }
}

class _ReminderSetupPage extends StatelessWidget {
  const _ReminderSetupPage({
    required this.dailyEnabled,
    required this.weeklyEnabled,
    required this.descriptive,
    required this.onDailyChanged,
    required this.onWeeklyChanged,
    required this.onDescriptiveChanged,
  });

  final bool dailyEnabled;
  final bool weeklyEnabled;
  final bool descriptive;

  final ValueChanged<bool> onDailyChanged;

  final ValueChanged<bool> onWeeklyChanged;

  final ValueChanged<bool> onDescriptiveChanged;

  @override
  Widget build(BuildContext context) {
    return _SetupPageFrame(
      icon: Icons.notifications_outlined,
      title: 'Would reminders help?',
      body: 'Reminders are optional and stay off unless you choose them. Default times are 8:00 AM for Daily Recovery and Sunday at 7:00 PM for Weekly Review.',
      child: Column(
        children: [
          SwitchListTile(
            key: const ValueKey('initial-daily-reminder'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily Recovery reminder'),
            subtitle: const Text('8:00 AM'),
            value: dailyEnabled,
            onChanged: onDailyChanged,
          ),
          SwitchListTile(
            key: const ValueKey('initial-weekly-reminder'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Weekly Review reminder'),
            subtitle: const Text('Sunday at 7:00 PM'),
            value: weeklyEnabled,
            onChanged: onWeeklyChanged,
          ),
          const Divider(),
          SwitchListTile(
            key: const ValueKey('initial-descriptive-notifications'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Show recovery wording in notifications'),
            subtitle: const Text(
              'Leave this off for more private notification text.',
            ),
            value: descriptive,
            onChanged: onDescriptiveChanged,
          ),
        ],
      ),
    );
  }
}

class _SetupPageFrame extends StatelessWidget {
  const _SetupPageFrame({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
      child: Column(
        children: [
          Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 30),
          child,
        ],
      ),
    );
  }
}
