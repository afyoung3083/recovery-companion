import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/local_step_work_repository.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(values);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

void main() {
  late Directory directory;
  late LocalRecoveryStore store;
  late LocalStepWorkRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'step_work_editing_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}'
        '${Platform.pathSeparator}'
        'recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    repository = LocalStepWorkRepository(store: store);

    await repository.setCurrentStep(8);

    await repository.createAssignment('Mispelled assignment');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('assignment text can be corrected', () async {
    final updated = await repository.updateAssignment(
      assignmentId: 1,
      text: 'Corrected assignment',
    );

    expect((updated['assignment'] as Map)['text'], 'Corrected assignment');

    final result = await repository.getStepWork();

    final stepWork = result['step_work'] as Map;

    final assignments = stepWork['assignments'] as List;

    expect((assignments.first as Map)['text'], 'Corrected assignment');
  });

  test('completed assignment can be reopened', () async {
    await repository.setAssignmentCompleted(assignmentId: 1, completed: true);

    var result = await repository.getStepWork();

    var assignment =
        ((result['step_work'] as Map)['assignments'] as List).first as Map;

    expect(assignment['completed'], isTrue);

    expect(assignment['completed_at'], isNotNull);

    await repository.setAssignmentCompleted(assignmentId: 1, completed: false);

    result = await repository.getStepWork();

    assignment =
        ((result['step_work'] as Map)['assignments'] as List).first as Map;

    expect(assignment['completed'], isFalse);

    expect(assignment['completed_at'], isNull);
  });

  test('empty assignment edit is rejected', () async {
    await expectLater(
      repository.updateAssignment(assignmentId: 1, text: '   '),
      throwsArgumentError,
    );
  });
}
