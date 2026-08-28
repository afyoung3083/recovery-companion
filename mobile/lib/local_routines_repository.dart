import 'local_recovery_store.dart';

class LocalRoutinesRepository {
  LocalRoutinesRepository({required this.store});

  final LocalRecoveryStore store;

  Future<Map<String, dynamic>> getRoutines() async {
    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    final routines = _routinesFromData(data);

    final active = routines
        .where((routine) => routine['active'] != false)
        .map((routine) => Map<String, dynamic>.from(routine))
        .toList();

    return {'routines': active};
  }

  Future<Map<String, dynamic>> createRoutine({
    required String text,
    required String area,
    required String frequency,
    String dayOfWeek = '',
  }) async {
    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    final routines = _routinesFromData(data);

    var nextId = 1;

    for (final routine in routines) {
      final id = routine['id'];

      if (id is int && id >= nextId) {
        nextId = id + 1;
      }
    }

    final routine = <String, dynamic>{
      'id': nextId,
      'text': text,
      'area': area,
      'frequency': frequency,
      'day_of_week': frequency == 'weekly' ? dayOfWeek : '',
      'active': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    routines.add(routine);

    data['routines'] = routines;

    await store.write(data);

    return {'routine': routine};
  }

  Future<Map<String, dynamic>> setRoutineActive({
    required int routineId,
    required bool active,
  }) async {
    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    final routines = _routinesFromData(data);

    final index = routines.indexWhere((routine) => routine['id'] == routineId);

    if (index < 0) {
      throw StateError('Routine $routineId was not found.');
    }

    routines[index] = {
      ...routines[index],
      'active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    data['routines'] = routines;

    await store.write(data);

    return {'routine': routines[index]};
  }

  List<Map<String, dynamic>> _routinesFromData(Map<String, dynamic> data) {
    final rawRoutines = data['routines'];

    if (rawRoutines is! List) {
      return [];
    }

    return rawRoutines
        .whereType<Map>()
        .map((routine) => Map<String, dynamic>.from(routine))
        .toList();
  }
}
