import 'local_recovery_store.dart';

class LocalStepWorkRepository {
  LocalStepWorkRepository({required this.store});

  final LocalRecoveryStore store;

  Future<Map<String, dynamic>> getStepWork() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final raw = data['step_work'];
    final stepWork = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{
            'current_step': 1,
            'assignments': <Map<String, dynamic>>[],
          };

    stepWork.putIfAbsent('current_step', () => 1);
    stepWork.putIfAbsent('assignments', () => <Map<String, dynamic>>[]);

    return {'step_work': stepWork};
  }

  Future<Map<String, dynamic>> setCurrentStep(int stepNumber) async {
    if (stepNumber < 1 || stepNumber > 12) {
      throw ArgumentError.value(
        stepNumber,
        'stepNumber',
        'Step must be between 1 and 12.',
      );
    }

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final raw = data['step_work'];
    final stepWork = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    stepWork['current_step'] = stepNumber;
    stepWork.putIfAbsent('assignments', () => <Map<String, dynamic>>[]);

    data['step_work'] = stepWork;

    await store.write(data);

    return {'step_work': stepWork};
  }

  Future<Map<String, dynamic>> createAssignment(String text) async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final raw = data['step_work'];
    final stepWork = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    final currentStep = stepWork['current_step'] is int
        ? stepWork['current_step'] as int
        : 1;

    final rawAssignments = stepWork['assignments'];

    final assignments = rawAssignments is List
        ? rawAssignments
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    var nextId = 1;

    for (final assignment in assignments) {
      final id = assignment['id'];

      if (id is int && id >= nextId) {
        nextId = id + 1;
      }
    }

    final assignment = <String, dynamic>{
      'id': nextId,
      'step': currentStep,
      'text': text,
      'completed': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    assignments.add(assignment);

    stepWork['current_step'] = currentStep;
    stepWork['assignments'] = assignments;

    data['step_work'] = stepWork;

    await store.write(data);

    return {'assignment': assignment};
  }

  Future<Map<String, dynamic>> completeAssignment(int assignmentId) async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final raw = data['step_work'];
    final stepWork = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};

    final rawAssignments = stepWork['assignments'];

    final assignments = rawAssignments is List
        ? rawAssignments
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    final index = assignments.indexWhere(
      (assignment) => assignment['id'] == assignmentId,
    );

    if (index < 0) {
      throw StateError('Assignment $assignmentId was not found.');
    }

    assignments[index] = {
      ...assignments[index],
      'completed': true,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    };

    stepWork['assignments'] = assignments;
    stepWork.putIfAbsent('current_step', () => 1);

    data['step_work'] = stepWork;

    await store.write(data);

    return {'assignment': assignments[index]};
  }
}
