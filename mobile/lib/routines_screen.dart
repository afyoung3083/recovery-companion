import 'package:flutter/material.dart';

import 'api_client.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
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

  static const List<String> _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  late Future<Map<String, dynamic>> _routinesFuture;

  final TextEditingController _textController =
      TextEditingController();

  String _area = 'other';
  String _frequency = 'daily';
  String _dayOfWeek = 'monday';
  bool _saving = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _routinesFuture = widget.apiClient.getRoutines();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _routinesFuture = widget.apiClient.getRoutines();
      _actionError = null;
    });
  }

  Future<void> _refreshAsync() async {
    final future = widget.apiClient.getRoutines();

    setState(() {
      _routinesFuture = future;
      _actionError = null;
    });

    await future;
  }

  Future<void> _createRoutine() async {
    final text = _textController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _actionError = 'Routine text is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _actionError = null;
    });

    try {
      await widget.apiClient.createRoutine(
        text: text,
        area: _area,
        frequency: _frequency,
        dayOfWeek: _frequency == 'weekly'
            ? _dayOfWeek
            : '',
      );

      if (!mounted) {
        return;
      }

      _textController.clear();

      setState(() {
        _area = 'other';
        _frequency = 'daily';
        _dayOfWeek = 'monday';
      });

      await _refreshAsync();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Routine added.'),
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

  Future<void> _setActive({
    required int routineId,
    required bool active,
  }) async {
    setState(() {
      _saving = true;
      _actionError = null;
    });

    try {
      await widget.apiClient.setRoutineActive(
        routineId: routineId,
        active: active,
      );

      if (!mounted) {
        return;
      }

      await _refreshAsync();
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

  List<Map<String, dynamic>> _routinesFrom(
    Map<String, dynamic>? data,
  ) {
    final rawRoutines = data?['routines'];

    if (rawRoutines is! List) {
      return [];
    }

    return rawRoutines
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Routines',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Build repeatable practices that support recovery.',
        ),
        const SizedBox(height: 24),

        Text(
          'Add Routine',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _textController,
          decoration: const InputDecoration(
            labelText: 'Routine',
            hintText: 'What practice do you want to repeat?',
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

        DropdownButtonFormField<String>(
          initialValue: _frequency,
          decoration: const InputDecoration(
            labelText: 'Frequency',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: 'daily',
              child: Text('Daily'),
            ),
            DropdownMenuItem(
              value: 'weekly',
              child: Text('Weekly'),
            ),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _frequency = value;
                    });
                  }
                },
        ),

        if (_frequency == 'weekly') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _dayOfWeek,
            decoration: const InputDecoration(
              labelText: 'Day of week',
              border: OutlineInputBorder(),
            ),
            items: _days
                .map(
                  (day) => DropdownMenuItem(
                    value: day,
                    child: Text(
                      _capitalize(day),
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _dayOfWeek = value;
                      });
                    }
                  },
          ),
        ],

        const SizedBox(height: 12),

        FilledButton.icon(
          onPressed: _saving ? null : _createRoutine,
          icon: const Icon(
            Icons.add,
          ),
          label: const Text(
            'Add Routine',
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
                'Active Routines',
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
          future: _routinesFuture,
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

            final routines = _routinesFrom(
              snapshot.data,
            );

            if (routines.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.repeat_outlined,
                        size: 44,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No active routines',
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: routines
                  .map(
                    (routine) => _buildRoutineCard(
                      routine,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoutineCard(
    Map<String, dynamic> routine,
  ) {
    final id = routine['id'] as int?;

    final text = (
      routine['text'] ??
      routine['routine'] ??
      'Recovery routine'
    ).toString();

    final area = (
      routine['area'] ??
      'other'
    ).toString();

    final frequency = (
      routine['frequency'] ??
      ''
    ).toString();

    final dayOfWeek = (
      routine['day_of_week'] ??
      ''
    ).toString();

    final schedule = dayOfWeek.isNotEmpty
        ? '${_capitalize(frequency)} - '
            '${_capitalize(dayOfWeek)}'
        : _capitalize(frequency);

    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.repeat,
        ),
        title: Text(
          text,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              'Area: ${_displayArea(area)}',
            ),
            if (schedule.isNotEmpty)
              Text(
                'Schedule: $schedule',
              ),
          ],
        ),
        trailing: Switch(
          value: true,
          onChanged: _saving || id == null
              ? null
              : (value) {
                  _setActive(
                    routineId: id,
                    active: value,
                  );
                },
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

    return _capitalize(area);
  }

  static String _capitalize(
    String value,
  ) {
    if (value.isEmpty) {
      return '';
    }

    return '${value[0].toUpperCase()}${value.substring(1)}';
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
              'Unable to load routines',
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