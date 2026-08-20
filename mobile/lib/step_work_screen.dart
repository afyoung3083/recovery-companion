import 'package:flutter/material.dart';

import 'api_client.dart';

class StepWorkScreen extends StatefulWidget {
  const StepWorkScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<StepWorkScreen> createState() => _StepWorkScreenState();
}

class _StepWorkScreenState extends State<StepWorkScreen> {
  late Future<Map<String, dynamic>> _stepWorkFuture;

  final TextEditingController _assignmentController =
      TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStepWork();
  }

  @override
  void dispose() {
    _assignmentController.dispose();
    super.dispose();
  }

  void _loadStepWork() {
    setState(() {
      _error = null;
      _stepWorkFuture = widget.apiClient.getStepWork();
    });
  }

  Future<void> _changeStep(
    int stepNumber,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.apiClient.setCurrentStep(
        stepNumber,
      );

      if (!mounted) {
        return;
      }

      _loadStepWork();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
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
        _error = 'Assignment cannot be empty.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.apiClient.createStepAssignment(
        text,
      );

      if (!mounted) {
        return;
      }

      _assignmentController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Step Work assignment added.',
          ),
        ),
      );

      _loadStepWork();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _completeAssignment(
    int assignmentId,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.apiClient.completeStepAssignment(
        assignmentId,
      );

      if (!mounted) {
        return;
      }

      _loadStepWork();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _stepWorkFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snapshot.error.toString(),
              ),
            ),
          );
        }

        final response = snapshot.data ?? const {};
        final rawStepWork = response['step_work'];

        final stepWork =
            rawStepWork is Map<String, dynamic>
                ? rawStepWork
                : <String, dynamic>{};

        final currentStep =
            stepWork['current_step'] is int
                ? stepWork['current_step'] as int
                : 1;

        final rawAssignments =
            stepWork['assignments'];

        final assignments = rawAssignments is List
            ? rawAssignments
                .whereType<Map<String, dynamic>>()
                .where(
                  (assignment) =>
                      assignment['step'] ==
                      currentStep,
                )
                .toList()
            : <Map<String, dynamic>>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Step Work',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              initialValue: currentStep,
              decoration: const InputDecoration(
                labelText: 'Current Step',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                12,
                (index) {
                  final step = index + 1;

                  return DropdownMenuItem(
                    value: step,
                    child: Text(
                      'Step $step',
                    ),
                  );
                },
              ),
              onChanged: _saving
                  ? null
                  : (step) {
                      if (step != null &&
                          step != currentStep) {
                        _changeStep(step);
                      }
                    },
            ),

            const SizedBox(height: 24),

            Text(
              'Step $currentStep Assignments',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _assignmentController,
              decoration: const InputDecoration(
                labelText: 'New assignment',
                hintText: 'Enter Step Work assignment',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (!_saving) {
                  _addAssignment();
                }
              },
            ),

            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed:
                  _saving ? null : _addAssignment,
              icon: const Icon(
                Icons.add_task,
              ),
              label: const Text(
                'Add Assignment',
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .error,
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (assignments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No assignments for this step.',
                  ),
                ),
              )
            else
              ...assignments.map(
                (assignment) {
                  final id =
                      assignment['id'] as int?;

                  final text =
                      (assignment['text'] ?? '')
                          .toString();

                  final completed =
                      assignment['completed'] ==
                          true;

                  return Card(
                    child: CheckboxListTile(
                      value: completed,
                      onChanged:
                          completed ||
                                  _saving ||
                                  id == null
                              ? null
                              : (_) {
                                  _completeAssignment(
                                    id,
                                  );
                                },
                      title: Text(text),
                      subtitle: completed
                          ? const Text(
                              'Completed',
                            )
                          : const Text(
                              'Open',
                            ),
                      controlAffinity:
                          ListTileControlAffinity
                              .leading,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}