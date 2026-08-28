import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'local_recovery_store.dart';

class LocalDataOwnershipRepository {
  LocalDataOwnershipRepository({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final LocalRecoveryStore store;
  final DateTime Function() _now;

  Future<Map<String, dynamic>> exportRecoveryData() async {
    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    final createdAt = _now().toUtc().toIso8601String();

    final hashInput = jsonEncode({
      'schema_version': LocalRecoveryStore.dataSchemaVersion,
      'data': data,
    });

    final digest = await Sha256().hash(utf8.encode(hashInput));

    final sha256 = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return {
      'export': {
        'metadata': {
          'created_at': createdAt,
          'schema_version': LocalRecoveryStore.dataSchemaVersion,
          'sha256': sha256,
          'source': 'local_device',
        },
        'data': data,
      },
    };
  }

  Future<void> deleteRecoveryData({required String confirmation}) async {
    if (confirmation != 'DELETE MY RECOVERY DATA') {
      throw ArgumentError.value(
        confirmation,
        'confirmation',
        'Confirmation phrase does not match.',
      );
    }

    await store.deleteAll();
  }
}
