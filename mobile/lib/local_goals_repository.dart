import 'local_recovery_store.dart';

class LocalGoalsRepository {
  LocalGoalsRepository({required this.store});

  final LocalRecoveryStore store;

  Future<Map<String, dynamic>> getGoals() async {
    final goals = await _readGoals();

    final active = goals
        .where((goal) => goal['active'] != false)
        .map((goal) => Map<String, dynamic>.from(goal))
        .toList();

    return {'goals': active};
  }

  Future<Map<String, dynamic>> createGoal({
    required String text,
    required String area,
    String targetDate = '',
  }) async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);
    final goals = await _goalsFromData(data);

    var nextId = 1;
    for (final goal in goals) {
      final id = goal['id'];
      if (id is int && id >= nextId) {
        nextId = id + 1;
      }
    }

    final goal = <String, dynamic>{
      'id': nextId,
      'text': text,
      'area': area,
      'target_date': targetDate,
      'active': true,
      'completed': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    goals.add(goal);
    data['goals'] = goals;

    await store.write(data);

    return {'goal': goal};
  }

  Future<Map<String, dynamic>> completeGoal(int goalId) async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);
    final goals = await _goalsFromData(data);

    final index = goals.indexWhere((goal) => goal['id'] == goalId);

    if (index < 0) {
      throw StateError('Goal $goalId was not found.');
    }

    goals[index] = {
      ...goals[index],
      'active': false,
      'completed': true,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    };

    data['goals'] = goals;
    await store.write(data);

    return {'goal': goals[index]};
  }

  Future<List<Map<String, dynamic>>> _readGoals() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);
    return _goalsFromData(data);
  }

  Future<List<Map<String, dynamic>>> _goalsFromData(
    Map<String, dynamic> data,
  ) async {
    final rawGoals = data['goals'];

    if (rawGoals is! List) {
      return [];
    }

    return rawGoals
        .whereType<Map>()
        .map((goal) => Map<String, dynamic>.from(goal))
        .toList();
  }
}
