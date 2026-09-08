import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'offline_copy_notice.dart';
import 'offline_read_service.dart';
import 'local_goals_repository.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    required this.apiClient,
    this.offlineReadService,
    this.localRepository,
    this.now,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineReadService? offlineReadService;
  final LocalGoalsRepository? localRepository;
  final DateTime Function()? now;

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

  late Future<OfflineReadResult> _goalsFuture;
  late Future<OfflineReadResult> _completedGoalsFuture;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _targetDateController = TextEditingController();

  String _area = 'other';
  bool _saving = false;
  bool _showingOfflineCopy = false;
  String? _actionError;

  Future<OfflineReadResult> _loadGoals() async {
    final localRepository = widget.localRepository;

    late final OfflineReadResult result;

    if (localRepository != null) {
      final data = await localRepository.getGoals();
      result = OfflineReadResult(data: data, source: OfflineReadSource.network);
    } else {
      final service = widget.offlineReadService;

      if (service == null) {
        final data = await widget.apiClient.getGoals();
        result = OfflineReadResult(
          data: data,
          source: OfflineReadSource.network,
        );
      } else {
        result = await service.read(
          cacheKey: OfflineCacheKeys.goals,
          networkRead: widget.apiClient.getGoals,
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

  Future<OfflineReadResult> _loadCompletedGoals() async {
    final localRepository = widget.localRepository;

    if (localRepository == null) {
      return const OfflineReadResult(
        data: {'goals': <Map<String, dynamic>>[]},
        source: OfflineReadSource.network,
      );
    }

    final data = await localRepository.getCompletedGoals();

    return OfflineReadResult(data: data, source: OfflineReadSource.network);
  }

  @override
  void initState() {
    super.initState();
    _goalsFuture = _loadGoals();
    _completedGoalsFuture = _loadCompletedGoals();
  }

  @override
  void dispose() {
    _textController.dispose();
    _targetDateController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _goalsFuture = _loadGoals();
      _completedGoalsFuture = _loadCompletedGoals();
      _actionError = null;
    });
  }

  Future<void> _refreshAsync() async {
    final goalsFuture = _loadGoals();
    final completedGoalsFuture = _loadCompletedGoals();

    setState(() {
      _goalsFuture = goalsFuture;
      _completedGoalsFuture = completedGoalsFuture;
      _actionError = null;
    });

    await Future.wait([goalsFuture, completedGoalsFuture]);
  }

  bool get _canEditTargetDate {
    return !_saving && !(_showingOfflineCopy && widget.localRepository == null);
  }

  DateTime _today() {
    final current = (widget.now ?? DateTime.now)();

    return DateTime(current.year, current.month, current.day);
  }

  DateTime _initialTargetDate({
    required DateTime today,
    required DateTime lastDate,
  }) {
    final parsed = DateTime.tryParse(_targetDateController.text.trim());

    if (parsed == null) {
      return today;
    }

    final normalized = DateTime(parsed.year, parsed.month, parsed.day);

    if (normalized.isBefore(today)) {
      return today;
    }

    if (normalized.isAfter(lastDate)) {
      return lastDate;
    }

    return normalized;
  }

  String _formatTargetDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Future<void> _chooseTargetDate() async {
    if (!_canEditTargetDate) {
      return;
    }

    final today = _today();

    final lastDate = DateTime(today.year + 20, 12, 31);

    final selected = await showDatePicker(
      context: context,
      initialDate: _initialTargetDate(today: today, lastDate: lastDate),
      firstDate: today,
      lastDate: lastDate,
      helpText: 'Choose goal target date',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _targetDateController.text = _formatTargetDate(selected);

      _actionError = null;
    });
  }

  void _clearTargetDate() {
    if (!_canEditTargetDate) {
      return;
    }

    setState(() {
      _targetDateController.clear();
      _actionError = null;
    });
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
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.createGoal(
          text: text,
          area: _area,
          targetDate: _targetDateController.text.trim(),
        );
      } else {
        await widget.apiClient.createGoal(
          text: text,
          area: _area,
          targetDate: _targetDateController.text.trim(),
        );
      }

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

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal added.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionError = 'Unable to save this goal. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _completeGoal(int goalId) async {
    setState(() {
      _saving = true;
      _actionError = null;
    });

    try {
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.completeGoal(goalId);
      } else {
        await widget.apiClient.completeGoal(goalId);
      }

      if (!mounted) {
        return;
      }

      await _refreshAsync();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal completed.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionError = 'Unable to complete this goal. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editGoal(Map<String, dynamic> goal) async {
    final localRepository = widget.localRepository;

    if (localRepository == null) {
      return;
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _GoalEditDialog(
        goal: goal,
        repository: localRepository,
        now: widget.now,
      ),
    );

    if (updated == true && mounted) {
      await _refreshAsync();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal updated.')));
    }
  }

  Future<void> _reactivateGoal(int goalId) async {
    final localRepository = widget.localRepository;

    if (localRepository == null) {
      return;
    }

    setState(() {
      _saving = true;
      _actionError = null;
    });

    try {
      await localRepository.reactivateGoal(goalId);
      if (!mounted) {
        return;
      }
      await _refreshAsync();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal reactivated.')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError = 'Unable to reactivate this goal. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteGoal(int goalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete goal?'),
        content: const Text(
          'Are you sure you want to permanently delete this goal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('goal-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final localRepository = widget.localRepository;

    if (localRepository == null) {
      return;
    }

    setState(() {
      _saving = true;
      _actionError = null;
    });

    try {
      await localRepository.deleteGoal(goalId);
      if (!mounted) {
        return;
      }
      await _refreshAsync();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal deleted.')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError = 'Unable to delete this goal. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _goalsFrom(Map<String, dynamic>? data) {
    final rawGoals = data?['goals'];

    if (rawGoals is! List) {
      return [];
    }

    return rawGoals.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppPageHeader(
          title: 'Goals',
          subtitle: 'Choose concrete recovery actions without turning recovery into a score.',
          icon: Icons.flag_outlined,
        ),

        const AppSectionTitle(
          title: 'Add a goal',
          subtitle: 'Keep it specific, realistic, and useful to your recovery.',
        ),

        AppSectionCard(
          key: const ValueKey('goals-add-card'),
          child: Column(
            children: [
              TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Goal',
                  hintText: 'What do you want to accomplish?',
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
              TextField(
                key: const ValueKey('goals-target-date-field'),
                controller: _targetDateController,
                readOnly: true,
                showCursor: false,
                enabled: _canEditTargetDate,
                onTap: _canEditTargetDate ? _chooseTargetDate : null,
                decoration: InputDecoration(
                  labelText: 'Target date',
                  hintText: 'Choose a date (optional)',
                  prefixIcon: const Icon(Icons.event_outlined),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_targetDateController.text.trim().isNotEmpty)
                        IconButton(
                          key: const ValueKey('goals-clear-target-date'),
                          tooltip: 'Clear target date',
                          onPressed: _canEditTargetDate
                              ? _clearTargetDate
                              : null,
                          icon: const Icon(Icons.clear),
                        ),
                      IconButton(
                        key: const ValueKey('goals-open-target-date-picker'),
                        tooltip: 'Choose target date',
                        onPressed: _canEditTargetDate
                            ? _chooseTargetDate
                            : null,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _saving ||
                          (_showingOfflineCopy &&
                              widget.localRepository == null)
                      ? null
                      : _createGoal,
                  icon: const Icon(Icons.add),
                  label: Text(_saving ? 'Saving...' : 'Add Goal'),
                ),
              ),
            ],
          ),
        ),

        if (_actionError != null) ...[
          const SizedBox(height: 12),
          Text(
            _actionError!,
            key: const ValueKey('goals-action-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],

        const SizedBox(height: 28),

        Row(
          children: [
            const Expanded(
              child: AppSectionTitle(
                title: 'Active Goals',
                subtitle: 'A few clear commitments can be enough.',
              ),
            ),
            IconButton(
              onPressed: _saving ? null : _refresh,
              tooltip: 'Refresh goals',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),

        FutureBuilder<OfflineReadResult>(
          future: _goalsFuture,
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
                title: 'Unable to load goals',
                message:
                    'Recovery Companion could not load your current goals.',
                icon: Icons.cloud_off_outlined,
                actionLabel: 'Retry',
                onAction: _refresh,
              );
            }

            final readResult = snapshot.data!;
            final goals = _goalsFrom(readResult.data);

            return Column(
              children: [
                if (readResult.isCached) ...[
                  OfflineCopyNotice(
                    cachedAt: readResult.cachedAt,
                    onRetry: _refresh,
                    detail:
                        'Adding or completing goals '
                        'still requires a connection.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (goals.isEmpty)
                  const AppStatusMessage(
                    title: 'No active goals',
                    message:
                        'Add a recovery goal when there is '
                        'something specific you want to work toward.',
                    icon: Icons.flag_outlined,
                  )
                else
                  for (final goal in goals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GoalCard(
                        goal: goal,
                        saving:
                            _saving ||
                            (readResult.isCached &&
                                widget.localRepository == null),
                        onComplete: _completeGoal,
                        onEdit: widget.localRepository == null
                            ? null
                            : _editGoal,
                        onDelete: widget.localRepository == null
                            ? null
                            : _deleteGoal,
                      ),
                    ),
              ],
            );
          },
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Completed Goals',
          subtitle: 'A record of goals you have finished.',
        ),

        FutureBuilder<OfflineReadResult>(
          future: _completedGoalsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return const AppStatusMessage(
                title: 'Completed goals unavailable',
                message: 'Recovery Companion could not load completed goals.',
                icon: Icons.flag_outlined,
              );
            }

            final goals = _goalsFrom(snapshot.data!.data);

            if (goals.isEmpty) {
              return const AppStatusMessage(
                title: 'No completed goals yet.',
                message: 'Completed goals will remain available here.',
                icon: Icons.flag_outlined,
              );
            }

            return Column(
              children: [
                for (final goal in goals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GoalCard(
                      goal: goal,
                      completed: true,
                      saving: false,
                      onEdit: widget.localRepository == null ? null : _editGoal,
                      onReactivate: widget.localRepository == null
                          ? null
                          : _reactivateGoal,
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

    if (area.isEmpty) {
      return 'Other';
    }

    return '${area[0].toUpperCase()}'
        '${area.substring(1)}';
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.saving,
    this.onComplete,
    this.onEdit,
    this.onReactivate,
    this.onDelete,
    this.completed = false,
  });

  final Map<String, dynamic> goal;
  final bool saving;
  final Future<void> Function(int)? onComplete;
  final Future<void> Function(Map<String, dynamic>)? onEdit;
  final Future<void> Function(int)? onReactivate;
  final Future<void> Function(int)? onDelete;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final id = goal['id'] as int?;

    final text = (goal['text'] ?? goal['goal'] ?? 'Recovery goal').toString();

    final area = (goal['area'] ?? 'other').toString();

    final targetDate = (goal['target_date'] ?? '').toString();

    final completedAt = (goal['completed_at'] ?? goal['completed_date'] ?? '')
        .toString();

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
                  Icons.flag_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.category_outlined, size: 18),
                label: Text(_GoalsScreenState._displayArea(area)),
              ),
              if (targetDate.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.event_outlined, size: 18),
                  label: Text(targetDate),
                ),
              if (completed)
                Chip(
                  avatar: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    completedAt.isEmpty
                        ? 'Completed'
                        : 'Completed $completedAt',
                  ),
                ),
            ],
          ),
          if (onEdit != null ||
              onReactivate != null ||
              onDelete != null ||
              !completed) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onEdit != null)
                  OutlinedButton.icon(
                    key: ValueKey('goal-edit-$id'),
                    onPressed: saving
                        ? null
                        : () {
                            onEdit!(goal);
                          },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                if (completed && onReactivate != null && id != null)
                  FilledButton.tonalIcon(
                    key: ValueKey('goal-reactivate-$id'),
                    onPressed: saving ? null : () => onReactivate!(id),
                    icon: const Icon(Icons.undo_outlined),
                    label: const Text('Reactivate'),
                  ),
                if (!completed)
                  FilledButton.tonalIcon(
                    key: ValueKey('goal-complete-$id'),
                    onPressed: saving || id == null || onComplete == null
                        ? null
                        : () {
                            onComplete!(id);
                          },
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                  ),
                if (!completed && onDelete != null && id != null)
                  OutlinedButton.icon(
                    key: ValueKey('goal-delete-$id'),
                    onPressed: saving ? null : () => onDelete!(id),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalEditDialog extends StatefulWidget {
  const _GoalEditDialog({
    required this.goal,
    required this.repository,
    this.now,
  });

  final Map<String, dynamic> goal;
  final LocalGoalsRepository repository;
  final DateTime Function()? now;

  @override
  State<_GoalEditDialog> createState() => _GoalEditDialogState();
}

class _GoalEditDialogState extends State<_GoalEditDialog> {
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

  late final TextEditingController _textController;
  late final TextEditingController _targetDateController;
  late String _area;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: (widget.goal['text'] ?? widget.goal['goal'] ?? '').toString(),
    );
    _targetDateController = TextEditingController(
      text: (widget.goal['target_date'] ?? '').toString(),
    );
    final rawArea = (widget.goal['area'] ?? 'other').toString();
    _area = _areas.contains(rawArea) ? rawArea : 'other';
  }

  @override
  void dispose() {
    _textController.dispose();
    _targetDateController.dispose();
    super.dispose();
  }

  DateTime _today() {
    final current = (widget.now ?? DateTime.now)();
    return DateTime(current.year, current.month, current.day);
  }

  Future<void> _chooseTargetDate() async {
    final today = _today();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_targetDateController.text) ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 20, 12, 31),
      helpText: 'Choose goal target date',
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _targetDateController.text =
          '${selected.year.toString().padLeft(4, '0')}-'
          '${selected.month.toString().padLeft(2, '0')}-'
          '${selected.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    final goalId = widget.goal['id'];
    final text = _textController.text.trim();
    if (goalId is! int) {
      setState(() {
        _error = 'This goal cannot be edited because its ID is missing.';
      });
      return;
    }
    if (text.isEmpty) {
      setState(() {
        _error = 'Goal text is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.repository.updateGoal(
        goalId: goalId,
        text: text,
        area: _area,
        targetDate: _targetDateController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to update this goal. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Goal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('goal-edit-text'),
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Goal'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const ValueKey('goal-edit-area'),
              initialValue: _area,
              decoration: const InputDecoration(labelText: 'Recovery area'),
              items: _areas
                  .map(
                    (area) => DropdownMenuItem(
                      value: area,
                      child: Text(_GoalsScreenState._displayArea(area)),
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
            TextField(
              key: const ValueKey('goal-edit-target-date'),
              controller: _targetDateController,
              readOnly: true,
              onTap: _saving ? null : _chooseTargetDate,
              decoration: const InputDecoration(
                labelText: 'Target date',
                prefixIcon: Icon(Icons.event_outlined),
              ),
            ),
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
          key: const ValueKey('goal-edit-save'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save Changes'),
        ),
      ],
    );
  }
}
