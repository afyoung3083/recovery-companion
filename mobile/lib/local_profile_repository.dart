import 'local_recovery_store.dart';

class LocalProfileRepository {
  LocalProfileRepository({required this.store});

  final LocalRecoveryStore store;

  Future<Map<String, dynamic>> getProfile() async {
    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final rawProfile = data['profile'];

    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : <String, dynamic>{};

    return {'profile': profile};
  }

  Future<Map<String, dynamic>> updateSobrietyDate(String sobrietyDate) async {
    final parsed = DateTime.tryParse(sobrietyDate);

    if (parsed == null) {
      throw ArgumentError.value(
        sobrietyDate,
        'sobrietyDate',
        'Must be a valid YYYY-MM-DD date.',
      );
    }

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    final rawProfile = data['profile'];

    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : <String, dynamic>{};

    profile['sobriety_date'] = sobrietyDate;
    data['profile'] = profile;

    await store.write(data);

    return {'profile': profile};
  }
}
