import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'offline_copy_notice.dart';
import 'offline_read_service.dart';
import 'local_routines_repository.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({
    required this.apiClient,
    this.offlineReadService,
    this.localRepository,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineReadService? offlineReadService;
  final LocalRoutinesRepository? localRepository;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

enum _RoutineViewMode { list, card }

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

  late Future<OfflineReadResult> _routinesFuture;
  late Future<List<Map<String, dynamic>>> _inactiveRoutinesFuture;

  final TextEditingController _textController = TextEditingController();

  String _area = 'other';
  String _frequency = 'daily';
  String _dayOfWeek = 'monday';
  bool _saving = false;
  bool _showingOfflineCopy = false;
  String? _actionError;
  _RoutineViewMode _viewMode = _RoutineViewMode.list;

  Future<OfflineReadResult> _loadRoutines() async {
    final localRepository = widget.localRepository;

    late final OfflineReadResult result;

    if (localRepository != null) {
      final data = await localRepository.getRoutines();

      result = OfflineReadResult(data: data, source: OfflineReadSource.network);
    } else {
      final service = widget.offlineReadService;

      if (service == null) {
        final data = await widget.apiClient.getRoutines();

        result = OfflineReadResult(
          data: data,
          source: OfflineReadSource.network,
        );
      } else {
        result = await service.read(
          cacheKey: OfflineCacheKeys.routines,
          networkRead: widget.apiClient.getRoutines,
        );
      }
    }

    if (mounted && _showingOfflineCopy != result.isCached) {
      setState(() {
        _showingOfflineCopy = result.isCached;
      });
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> _loadInactiveRoutines() async {
    final localRepository = widget.localRepository;

    if (localRepository == null) {
      return const [];
    }

    return localRepository.getInactiveRoutines();
  }

  @override
  void initState() {
    super.initState();
    _routinesFuture = _loadRoutines();
    _inactiveRoutinesFuture = _loadInactiveRoutines();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _routinesFuture = _loadRoutines();
      _inactiveRoutinesFuture = _loadInactiveRoutines();
      _actionError = null;
    });
  }

  Future<void> _refreshAsync() async {
    final routinesFuture = _loadRoutines();
    final inactiveFuture = _loadInactiveRoutines();

    setState(() {
      _routinesFuture = routinesFuture;
      _inactiveRoutinesFuture = inactiveFuture;
      _actionError = null;
    });

    await Future.wait([routinesFuture, inactiveFuture]);
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
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.createRoutine(
          text: text,
          area: _area,
          frequency: _frequency,
          dayOfWeek: _frequency == 'weekly' ? _dayOfWeek : '',
        );
      } else {
        await widget.apiClient.createRoutine(
          text: text,
          area: _area,
          frequency: _frequency,
          dayOfWeek: _frequency == 'weekly' ? _dayOfWeek : '',
        );
      }

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
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.setRoutineActive(
          routineId: routineId,
          active: active,
        );
      } else {
        await widget.apiClient.setRoutineActive(
          routineId: routineId,
          active: active,
        );
      }

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

  Future<void> _editRoutine(Map<String, dynamic> routine) async {
    final localRepository = widget.localRepository;

    if (localRepository == null) {
      return;
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _RoutineEditDialog(routine: routine, repository: localRepository),
    );

    if (updated == true && mounted) {
      await _refreshAsync();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Routine updated.')));
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
                onChanged:
                    _saving ||
                        (_showingOfflineCopy && widget.localRepository == null)
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
                onChanged:
                    _saving ||
                        (_showingOfflineCopy && widget.localRepository == null)
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
                  onChanged:
                      _saving ||
                          (_showingOfflineCopy &&
                              widget.localRepository == null)
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
                  onPressed:
                      _saving ||
                          (_showingOfflineCopy &&
                              widget.localRepository == null)
                      ? null
                      : _createRoutine,
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

        Row(
          children: [
            const Text('View:'),
            const SizedBox(width: 8),
            ChoiceChip(
              key: const ValueKey('routines-view-list'),
              label: const Text('List'),
              selected: _viewMode == _RoutineViewMode.list,
              onSelected: (_) {
                setState(() {
                  _viewMode = _RoutineViewMode.list;
                });
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              key: const ValueKey('routines-view-card'),
              label: const Text('Card'),
              selected: _viewMode == _RoutineViewMode.card,
              onSelected: (_) {
                setState(() {
                  _viewMode = _RoutineViewMode.card;
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 12),

        FutureBuilder<OfflineReadResult>(
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

            final readResult = snapshot.data!;
            final routines = _routinesFrom(readResult.data);

            return Column(
              children: [
                if (readResult.isCached) ...[
                  OfflineCopyNotice(
                    cachedAt: readResult.cachedAt,
                    onRetry: _refresh,
                    detail:
                        'Adding or changing routines '
                        'still requires a connection.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (routines.isEmpty)
                  const AppStatusMessage(
                    title: 'No active routines',
                    message:
                        'Add a repeatable practice when there is '
                        'something you want to keep returning to.',
                    icon: Icons.repeat_outlined,
                  )
                else
                  for (final routine in routines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _viewMode == _RoutineViewMode.list
                          ? _RoutineListTile(
                              routine: routine,
                              saving:
                                  _saving ||
                                  (readResult.isCached &&
                                      widget.localRepository == null),
                              onSetActive: _setActive,
                              onEdit: widget.localRepository == null
                                  ? null
                                  : _editRoutine,
                            )
                          : _RoutineCard(
                              routine: routine,
                              saving:
                                  _saving ||
                                  (readResult.isCached &&
                                      widget.localRepository == null),
                              onSetActive: _setActive,
                              onEdit: widget.localRepository == null
                                  ? null
                                  : _editRoutine,
                            ),
                    ),
              ],
            );
          },
        ),

        if (widget.localRepository != null) ...[
          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'Inactive Routines',
            subtitle: 'Practices you have turned off but kept for later.',
          ),

          const SizedBox(height: 12),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _inactiveRoutinesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const AppStatusMessage(
                  title: 'Inactive routines unavailable',
                  message:
                      'Recovery Companion could not load inactive routines.',
                  icon: Icons.repeat_outlined,
                );
              }

              final inactiveRoutines = snapshot.data ?? const [];

              if (inactiveRoutines.isEmpty) {
                return const AppStatusMessage(
                  title: 'No inactive routines',
                  message: 'Routines you turn off will remain available here.',
                  icon: Icons.repeat_outlined,
                );
              }

              return Column(
                children: [
                  for (final routine in inactiveRoutines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _viewMode == _RoutineViewMode.list
                          ? _RoutineListTile(
                              routine: routine,
                              saving: _saving,
                              onSetActive: _setActive,
                              onEdit: _editRoutine,
                            )
                          : _RoutineCard(
                              routine: routine,
                              saving: _saving,
                              onSetActive: _setActive,
                              onEdit: _editRoutine,
                            ),
                    ),
                ],
              );
            },
          ),
        ],
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
    this.onEdit,
  });

  final Map<String, dynamic> routine;
  final bool saving;
  final Future<void> Function({required int routineId, required bool active})
  onSetActive;
  final Future<void> Function(Map<String, dynamic>)? onEdit;

  @override
  Widget build(BuildContext context) {
    final id = routine['id'] as int?;

    final text = (routine['text'] ?? routine['routine'] ?? 'Recovery routine')
        .toString();

    final area = (routine['area'] ?? 'other').toString();

    final frequency = (routine['frequency'] ?? '').toString();

    final dayOfWeek = (routine['day_of_week'] ?? '').toString();

    final schedule = _routineSchedule(frequency, dayOfWeek);

    final active = routine['active'] != false;

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        Chip(
                          label: Text(_RoutinesScreenState._displayArea(area)),
                        ),
                        if (schedule.isNotEmpty)
                          Chip(
                            avatar: const Icon(
                              Icons.schedule_outlined,
                              size: 18,
                            ),
                            label: Text(schedule),
                          ),
                        Chip(
                          avatar: Icon(
                            active
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            size: 18,
                          ),
                          label: Text(active ? 'Active' : 'Inactive'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: active,
                onChanged: saving || id == null
                    ? null
                    : (value) {
                        onSetActive(routineId: id, active: value);
                      },
              ),
            ],
          ),
          if (onEdit != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: ValueKey('routine-edit-$id'),
                onPressed: saving
                    ? null
                    : () {
                        onEdit!(routine);
                      },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutineListTile extends StatelessWidget {
  const _RoutineListTile({
    required this.routine,
    required this.saving,
    required this.onSetActive,
    this.onEdit,
  });

  final Map<String, dynamic> routine;
  final bool saving;
  final Future<void> Function({required int routineId, required bool active})
  onSetActive;
  final Future<void> Function(Map<String, dynamic>)? onEdit;

  @override
  Widget build(BuildContext context) {
    final id = routine['id'] as int?;

    final text = (routine['text'] ?? routine['routine'] ?? 'Recovery routine')
        .toString();

    final area = (routine['area'] ?? 'other').toString();

    final frequency = (routine['frequency'] ?? '').toString();

    final dayOfWeek = (routine['day_of_week'] ?? '').toString();

    final schedule = _routineSchedule(frequency, dayOfWeek);

    final active = routine['active'] != false;

    return ListTile(
      key: ValueKey('routine-tile-$id'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(Icons.repeat, color: Theme.of(context).colorScheme.primary),
      title: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${_RoutinesScreenState._displayArea(area)}'
        '${schedule.isEmpty ? '' : ' \u00b7 $schedule'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              key: ValueKey('routine-edit-$id'),
              tooltip: 'Edit routine',
              onPressed: saving
                  ? null
                  : () {
                      onEdit!(routine);
                    },
              icon: const Icon(Icons.edit_outlined),
            ),
          Switch(
            value: active,
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

String _routineSchedule(String frequency, String dayOfWeek) {
  final capFrequency = _RoutinesScreenState._capitalize(frequency);

  if (dayOfWeek.isEmpty) {
    return capFrequency;
  }

  return '$capFrequency \u00b7 ${_RoutinesScreenState._capitalize(dayOfWeek)}';
}

class _RoutineEditDialog extends StatefulWidget {
  const _RoutineEditDialog({required this.routine, required this.repository});

  final Map<String, dynamic> routine;
  final LocalRoutinesRepository repository;

  @override
  State<_RoutineEditDialog> createState() => _RoutineEditDialogState();
}

class _RoutineEditDialogState extends State<_RoutineEditDialog> {
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

  late final TextEditingController _textController;
  late String _area;
  late String _frequency;
  late String _dayOfWeek;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _textController = TextEditingController(
      text: (widget.routine['text'] ?? widget.routine['routine'] ?? '')
          .toString(),
    );

    final rawArea = (widget.routine['area'] ?? 'other').toString();
    _area = _areas.contains(rawArea) ? rawArea : 'other';

    final rawFrequency = (widget.routine['frequency'] ?? 'daily').toString();
    _frequency = rawFrequency == 'weekly' ? 'weekly' : 'daily';

    final rawDay = (widget.routine['day_of_week'] ?? '').toString();
    _dayOfWeek = _days.contains(rawDay) ? rawDay : 'monday';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final routineId = widget.routine['id'];
    final text = _textController.text.trim();

    if (routineId is! int) {
      setState(() {
        _error = 'This routine cannot be edited because its ID is missing.';
      });
      return;
    }

    if (text.isEmpty) {
      setState(() {
        _error = 'Routine text is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.repository.updateRoutine(
        routineId: routineId,
        text: text,
        area: _area,
        frequency: _frequency,
        dayOfWeek: _frequency == 'weekly' ? _dayOfWeek : '',
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to update this routine. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Routine'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('routine-edit-text'),
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Routine'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const ValueKey('routine-edit-area'),
              initialValue: _area,
              decoration: const InputDecoration(labelText: 'Recovery area'),
              items: _areas
                  .map(
                    (area) => DropdownMenuItem(
                      value: area,
                      child: Text(_RoutinesScreenState._displayArea(area)),
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
              key: const ValueKey('routine-edit-frequency'),
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
                key: const ValueKey('routine-edit-day'),
                initialValue: _dayOfWeek,
                decoration: const InputDecoration(labelText: 'Day of week'),
                items: _days
                    .map(
                      (day) => DropdownMenuItem(
                        value: day,
                        child: Text(_RoutinesScreenState._capitalize(day)),
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('routine-edit-save'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save Changes'),
        ),
      ],
    );
  }
}
