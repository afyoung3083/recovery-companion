import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'offline_copy_notice.dart';
import 'offline_read_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    required this.apiClient,
    this.offlineReadService,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineReadService? offlineReadService;

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

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _targetDateController = TextEditingController();

  String _area = 'other';
  bool _saving = false;
  bool _showingOfflineCopy = false;
  String? _actionError;

  Future<OfflineReadResult> _loadGoals() async {
    final service = widget.offlineReadService;

    late final OfflineReadResult result;

    if (service == null) {
      final data = await widget.apiClient.getGoals();

      result = OfflineReadResult(data: data, source: OfflineReadSource.network);
    } else {
      result = await service.read(
        cacheKey: OfflineCacheKeys.goals,
        networkRead: widget.apiClient.getGoals,
      );
    }

    if (mounted && _showingOfflineCopy != result.isCached) {
      setState(() {
        _showingOfflineCopy = result.isCached;
      });
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    _goalsFuture = _loadGoals();
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
      _actionError = null;
    });
  }

  Future<void> _refreshAsync() async {
    final future = _loadGoals();

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
      await widget.apiClient.completeGoal(goalId);

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
                onChanged: _saving || _showingOfflineCopy
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
                controller: _targetDateController,
                decoration: const InputDecoration(
                  labelText: 'Target date',
                  hintText: 'YYYY-MM-DD (optional)',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || _showingOfflineCopy
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
                        saving: _saving || readResult.isCached,
                        onComplete: _completeGoal,
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
    required this.onComplete,
  });

  final Map<String, dynamic> goal;
  final bool saving;
  final Future<void> Function(int) onComplete;

  @override
  Widget build(BuildContext context) {
    final id = goal['id'] as int?;

    final text = (goal['text'] ?? goal['goal'] ?? 'Recovery goal').toString();

    final area = (goal['area'] ?? 'other').toString();

    final targetDate = (goal['target_date'] ?? '').toString();

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
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: saving || id == null
                  ? null
                  : () {
                      onComplete(id);
                    },
              icon: const Icon(Icons.check),
              label: const Text('Complete'),
            ),
          ),
        ],
      ),
    );
  }
}
