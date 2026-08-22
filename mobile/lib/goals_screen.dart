import 'package:flutter/material.dart';

import 'api_client.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  static const List<String> _areas = [
    'connection',
    'step_work',
    'meetings',
    'prayer',
    'journal',
    'service',
    'health',
    'other',
  ];

  late Future<Map<String, dynamic>> _goalsFuture;

  final TextEditingController _textController =
      TextEditingController();
  final TextEditingController _targetDateController =
      TextEditingController();

  String _area = 'other';
  bool _saving = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _goalsFuture = widget.apiClient.getGoals();
  }

  @override
  void dispose() {
    _textController.dispose();
    _targetDateController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _goalsFuture = widget.apiClient.getGoals();
      _actionError = null;
    });
  }

  Future<void> _refreshAsync() async {
    final future = widget.apiClient.getGoals();

    setState(() {
      _goalsFuture = future;
      _actionError = null;
    });

    await future;
  }

  Future<void> _createGoal() async {
    final text = _textController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _actionError = 'Goal text is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _actionError = null;
    });

    try {
      await widget.apiClient.createGoal(
        text: text,
        area: _area,
        targetDate: _targetDateController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      _textController.clear();
      _targetDateController.clear();

      setState(() {
        _area = 'other';
      });

      await _refreshAsync();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goal added.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _completeGoal(
    int goalId,
  ) async {
    setState(() {
      _saving = true;
      _actionError = null;
    });

    try {
      await widget.apiClient.completeGoal(
        goalId,
      );

      if (!mounted) {
        return;
      }

      await _refreshAsync();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goal completed.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _goalsFrom(
    Map<String, dynamic>? data,
  ) {
    final rawGoals = data?['goals'];

    if (rawGoals is! List) {
      return [];
    }

    return rawGoals
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Goals',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Set concrete recovery goals and mark them complete.',
        ),
        const SizedBox(height: 24),

        Text(
          'Add Goal',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _textController,
          decoration: const InputDecoration(
            labelText: 'Goal',
            hintText: 'What do you want to accomplish?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          initialValue: _area,
          decoration: const InputDecoration(
            labelText: 'Recovery area',
            border: OutlineInputBorder(),
          ),
          items: _areas
              .map(
                (area) => DropdownMenuItem(
                  value: area,
                  child: Text(
                    _displayArea(area),
                  ),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _area = value;
                    });
                  }
                },
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _targetDateController,
          decoration: const InputDecoration(
            labelText: 'Target date',
            hintText: 'YYYY-MM-DD (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        FilledButton.icon(
          onPressed: _saving ? null : _createGoal,
          icon: const Icon(
            Icons.add,
          ),
          label: const Text(
            'Add Goal',
          ),
        ),

        if (_actionError != null) ...[
          const SizedBox(height: 12),
          Text(
            _actionError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],

        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: Text(
                'Active Goals',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: _saving ? null : _refresh,
              tooltip: 'Refresh',
              icon: const Icon(
                Icons.refresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        FutureBuilder<Map<String, dynamic>>(
          future: _goalsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return _ErrorCard(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final goals = _goalsFrom(
              snapshot.data,
            );

            if (goals.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 44,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No active goals',
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: goals
                  .map(
                    (goal) => _buildGoalCard(
                      goal,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGoalCard(
    Map<String, dynamic> goal,
  ) {
    final id = goal['id'] as int?;

    final text = (
      goal['text'] ??
      goal['goal'] ??
      'Recovery goal'
    ).toString();

    final area = (
      goal['area'] ??
      'other'
    ).toString();

    final targetDate = (
      goal['target_date'] ??
      ''
    ).toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Area: ${_displayArea(area)}',
            ),
            if (targetDate.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Target: $targetDate',
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _saving || id == null
                    ? null
                    : () {
                        _completeGoal(id);
                      },
                icon: const Icon(
                  Icons.check,
                ),
                label: const Text(
                  'Complete',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _displayArea(
    String area,
  ) {
    if (area == 'step_work') {
      return 'Step Work';
    }

    if (area.isEmpty) {
      return 'Other';
    }

    return '${area[0].toUpperCase()}${area.substring(1)}';
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load goals',
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}