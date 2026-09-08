import 'local_recovery_store.dart';

class LocalRoutinesRepository {
  LocalRoutinesRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LocalRecoveryStore store;
  final DateTime Function() _now;

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

  Future<List<Map<String, dynamic>>> getInactiveRoutines() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    return _routinesFromData(data)
        .where((routine) => routine['active'] == false)
        .map((routine) => Map<String, dynamic>.from(routine))
        .toList();
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
      'created_at': _now().toUtc().toIso8601String(),
    };

    routines.add(routine);

    data['routines'] = routines;

    await store.write(data);

    return {'routine': routine};
  }

  Future<Map<String, dynamic>> updateRoutine({
    required int routineId,
    required String text,
    required String area,
    required String frequency,
    required String dayOfWeek,
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
      'text': text,
      'area': area,
      'frequency': frequency,
      'day_of_week': frequency == 'weekly' ? dayOfWeek : '',
      'updated_at': _now().toUtc().toIso8601String(),
    };

    data['routines'] = routines;
    await store.write(data);

    return {'routine': routines[index]};
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
      'updated_at': _now().toUtc().toIso8601String(),
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
