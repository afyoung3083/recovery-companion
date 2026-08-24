import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({required this.apiClient, super.key});

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

  final TextEditingController _textController = TextEditingController();

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
        dayOfWeek: _frequency == 'weekly' ? _dayOfWeek : '',
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

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Routine added.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionError = 'Unable to save this routine. Please try again.';
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
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionError = 'Unable to update this routine. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _routinesFrom(Map<String, dynamic>? data) {
    final rawRoutines = data?['routines'];

    if (rawRoutines is! List) {
      return [];
    }

    return rawRoutines.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppPageHeader(
          title: 'Routines',
          subtitle: 'Build repeatable practices that support recovery one day at a time.',
          icon: Icons.repeat_outlined,
        ),

        const AppSectionTitle(
          title: 'Add a routine',
          subtitle: 'Create a practice you want to return to consistently.',
        ),

        AppSectionCard(
          key: const ValueKey('routines-add-card'),
          child: Column(
            children: [
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Routine',
                  hintText: 'What practice do you want to repeat?',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _area,
                decoration: const InputDecoration(labelText: 'Recovery area'),
                items: _areas
                    .map(
                      (area) => DropdownMenuItem(
                        value: area,
                        child: Text(_displayArea(area)),
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
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
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
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _dayOfWeek,
                  decoration: const InputDecoration(labelText: 'Day of week'),
                  items: _days
                      .map(
                        (day) => DropdownMenuItem(
                          value: day,
                          child: Text(_capitalize(day)),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _createRoutine,
                  icon: const Icon(Icons.add),
                  label: Text(_saving ? 'Saving...' : 'Add Routine'),
                ),
              ),
            ],
          ),
        ),

        if (_actionError != null) ...[
          const SizedBox(height: 12),
          Text(
            _actionError!,
            key: const ValueKey('routines-action-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],

        const SizedBox(height: 28),

        Row(
          children: [
            const Expanded(
              child: AppSectionTitle(
                title: 'Active Routines',
                subtitle: 'Practices you have chosen to keep in view.',
              ),
            ),
            IconButton(
              onPressed: _saving ? null : _refresh,
              tooltip: 'Refresh routines',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),

        FutureBuilder<Map<String, dynamic>>(
          future: _routinesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return AppStatusMessage(
                title: 'Unable to load routines',
                message:
                    'Recovery Companion could not load your active routines.',
                icon: Icons.cloud_off_outlined,
                actionLabel: 'Retry',
                onAction: _refresh,
              );
            }

            final routines = _routinesFrom(snapshot.data);

            if (routines.isEmpty) {
              return const AppStatusMessage(
                title: 'No active routines',
                message: 'Add a repeatable practice when there is something you want to keep returning to.',
                icon: Icons.repeat_outlined,
              );
            }

            return Column(
              children: [
                for (final routine in routines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RoutineCard(
                      routine: routine,
                      saving: _saving,
                      onSetActive: _setActive,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _displayArea(String area) {
    if (area == 'step_work') {
      return 'Step Work';
    }

    return _capitalize(area);
  }

  static String _capitalize(String value) {
    if (value.isEmpty) {
      return '';
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1)}';
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.saving,
    required this.onSetActive,
  });

  final Map<String, dynamic> routine;
  final bool saving;
  final Future<void> Function({required int routineId, required bool active})
  onSetActive;

  @override
  Widget build(BuildContext context) {
    final id = routine['id'] as int?;

    final text = (routine['text'] ?? routine['routine'] ?? 'Recovery routine')
        .toString();

    final area = (routine['area'] ?? 'other').toString();

    final frequency = (routine['frequency'] ?? '').toString();

    final dayOfWeek = (routine['day_of_week'] ?? '').toString();

    final schedule = dayOfWeek.isNotEmpty
        ? '${_RoutinesScreenState._capitalize(frequency)} ? '
              '${_RoutinesScreenState._capitalize(dayOfWeek)}'
        : _RoutinesScreenState._capitalize(frequency);

    return AppSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.repeat,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(_RoutinesScreenState._displayArea(area))),
                    if (schedule.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.schedule_outlined, size: 18),
                        label: Text(schedule),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: true,
            onChanged: saving || id == null
                ? null
                : (value) {
                    onSetActive(routineId: id, active: value);
                  },
          ),
        ],
      ),
    );
  }
}
