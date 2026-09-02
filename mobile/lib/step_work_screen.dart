import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'local_step_work_repository.dart';

class StepWorkScreen extends StatefulWidget {
  const StepWorkScreen({
    required this.apiClient,
    this.localRepository,
    super.key,
  });

  final ApiClient apiClient;
  final LocalStepWorkRepository? localRepository;

  @override
  State<StepWorkScreen> createState() => _StepWorkScreenState();
}

class _StepWorkScreenState extends State<StepWorkScreen> {
  late Future<Map<String, dynamic>> _stepWorkFuture;

  final TextEditingController _assignmentController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stepWorkFuture = widget.localRepository != null
        ? widget.localRepository!.getStepWork()
        : widget.apiClient.getStepWork();
  }

  @override
  void dispose() {
    _assignmentController.dispose();
    super.dispose();
  }

  void _loadStepWork() {
    setState(() {
      _error = null;
      _stepWorkFuture = widget.localRepository != null
          ? widget.localRepository!.getStepWork()
          : widget.apiClient.getStepWork();
    });
  }

  Future<void> _refresh() async {
    final future = widget.localRepository != null
        ? widget.localRepository!.getStepWork()
        : widget.apiClient.getStepWork();

    setState(() {
      _error = null;
      _stepWorkFuture = future;
    });

    await future;
  }

  Future<void> _changeStep(int stepNumber) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.setCurrentStep(stepNumber);
      } else {
        await widget.apiClient.setCurrentStep(stepNumber);
      }

      if (!mounted) {
        return;
      }

      _loadStepWork();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to update your current Step. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _addAssignment() async {
    final text = _assignmentController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _error = 'Enter an assignment before adding it.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.createAssignment(text);
      } else {
        await widget.apiClient.createStepAssignment(text);
      }

      if (!mounted) {
        return;
      }

      _assignmentController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Step Work assignment added.')),
      );

      _loadStepWork();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to add this Step Work assignment. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _setAssignmentCompleted(int assignmentId, bool completed) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.setAssignmentCompleted(
          assignmentId: assignmentId,
          completed: completed,
        );
      } else {
        await widget.apiClient.setStepAssignmentCompleted(
          assignmentId: assignmentId,
          completed: completed,
        );
      }

      if (!mounted) {
        return;
      }

      _loadStepWork();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Unable to update this assignment. '
            'Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editAssignment(Map<String, dynamic> assignment) async {
    final id = assignment['id'];

    if (id is! int) {
      return;
    }

    var draftText = (assignment['text'] ?? '').toString();

    final updatedText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Assignment'),
          content: TextFormField(
            key: const ValueKey('step-work-edit-input'),
            initialValue: draftText,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Assignment',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              draftText = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('step-work-save-edit'),
              onPressed: () {
                final value = draftText.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || updatedText == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.updateAssignment(
          assignmentId: id,
          text: updatedText,
        );
      } else {
        await widget.apiClient.updateStepAssignment(
          assignmentId: id,
          text: updatedText,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Step Work assignment updated.')),
      );

      _loadStepWork();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Unable to edit this assignment. '
            'Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _assignmentsForStep(
    Map<String, dynamic> stepWork,
    int currentStep,
  ) {
    final rawAssignments = stepWork['assignments'];

    if (rawAssignments is! List) {
      return [];
    }

    return rawAssignments
        .whereType<Map<String, dynamic>>()
        .where((assignment) => assignment['step'] == currentStep)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _stepWorkFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AppPageHeader(
                title: 'Step Work',
                subtitle:
                    'Stay with the work that is currently in front of you.',
                icon: Icons.format_list_numbered,
              ),
              AppStatusMessage(
                title: 'Unable to load Step Work',
                message: 'Recovery Companion could not load your current Step and assignments.',
                icon: Icons.cloud_off_outlined,
                actionLabel: 'Retry',
                onAction: _loadStepWork,
              ),
            ],
          );
        }

        final response = snapshot.data ?? const {};

        final rawStepWork = response['step_work'];

        final stepWork = rawStepWork is Map<String, dynamic>
            ? rawStepWork
            : <String, dynamic>{};

        final currentStep = stepWork['current_step'] is int
            ? stepWork['current_step'] as int
            : 1;

        final assignments = _assignmentsForStep(stepWork, currentStep);

        final openCount = assignments
            .where((assignment) => assignment['completed'] != true)
            .length;

        final completedCount = assignments.length - openCount;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const AppPageHeader(
                title: 'Step Work',
                subtitle:
                    'Stay with the work that is currently in front of you.',
                icon: Icons.format_list_numbered,
              ),

              Container(
                key: const ValueKey('step-work-current-step-card'),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface
                            .withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        '$currentStep',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Step',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Step $currentStep',
                            key: const ValueKey('step-work-current-step'),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$openCount open \u2022 $completedCount completed',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const AppSectionTitle(
                title: 'Current Step',
                subtitle: 'You choose when your current Step changes. Recovery Companion does not advance you automatically.',
              ),

              AppSectionCard(
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('step-work-step-selector'),
                  initialValue: currentStep,
                  decoration: const InputDecoration(
                    labelText: 'Current Step',
                    prefixIcon: Icon(Icons.format_list_numbered),
                  ),
                  items: List.generate(12, (index) {
                    final step = index + 1;

                    return DropdownMenuItem(
                      value: step,
                      child: Text('Step $step'),
                    );
                  }),
                  onChanged: _saving
                      ? null
                      : (step) {
                          if (step != null && step != currentStep) {
                            _changeStep(step);
                          }
                        },
                ),
              ),

              const SizedBox(height: 28),

              AppSectionTitle(
                title: 'Step $currentStep Assignments',
                subtitle: 'Keep sponsor-directed or personally chosen Step work in one place.',
              ),

              AppSectionCard(
                key: const ValueKey('step-work-add-assignment-card'),
                child: Column(
                  children: [
                    TextField(
                      key: const ValueKey('step-work-assignment-input'),
                      controller: _assignmentController,
                      decoration: const InputDecoration(
                        labelText: 'New assignment',
                        hintText: 'What is the next piece of Step work?',
                        prefixIcon: Icon(Icons.assignment_outlined),
                      ),
                      onSubmitted: (_) {
                        if (!_saving) {
                          _addAssignment();
                        }
                      },
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('step-work-add-assignment'),
                        onPressed: _saving ? null : _addAssignment,
                        icon: const Icon(Icons.add_task),
                        label: const Text('Add Assignment'),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                AppStatusMessage(
                  title: 'Step Work action unavailable',
                  message: _error!,
                  icon: Icons.error_outline,
                ),
              ],

              const SizedBox(height: 28),

              const AppSectionTitle(
                title: 'Assignments',
                subtitle: 'Completion is a record of your work, not a score.',
              ),

              if (assignments.isEmpty)
                const AppStatusMessage(
                  title: 'No assignments for this Step',
                  message: 'Add an assignment above when there is specific work you want to track.',
                  icon: Icons.task_alt_outlined,
                )
              else
                AppSectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < assignments.length;
                        index++
                      ) ...[
                        _AssignmentTile(
                          assignment: assignments[index],
                          saving: _saving,
                          onCompletedChanged: _setAssignmentCompleted,
                          onEdit: _editAssignment,
                        ),
                        if (index < assignments.length - 1)
                          const Divider(height: 1, indent: 68),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.saving,
    required this.onCompletedChanged,
    required this.onEdit,
  });

  final Map<String, dynamic> assignment;
  final bool saving;

  final void Function(int assignmentId, bool completed) onCompletedChanged;

  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) {
    final id = assignment['id'];

    final text = (assignment['text'] ?? '').toString();

    final completed = assignment['completed'] == true;

    return ListTile(
      key: ValueKey('step-work-assignment-$id'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Tooltip(
        message: completed
            ? 'Mark assignment incomplete'
            : 'Mark assignment complete',
        child: Checkbox(
          key: ValueKey('step-work-completed-$id'),
          value: completed,
          onChanged: saving || id is! int
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }

                  onCompletedChanged(id, value);
                },
        ),
      ),
      title: Text(
        text,
        style: TextStyle(
          decoration: completed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(completed ? 'Completed' : 'Open'),
      trailing: IconButton(
        key: ValueKey('step-work-edit-$id'),
        tooltip: 'Edit assignment',
        onPressed: saving || id is! int
            ? null
            : () {
                onEdit(assignment);
              },
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}
