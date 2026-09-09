import 'dart:io';

import 'package:flutter/services.dart';

class RecoveryBackupProtectionStatus {
  const RecoveryBackupProtectionStatus({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  bool get isHealthy => false;

  @override
  String toString() => 'RecoveryBackupProtectionStatus(code: $code)';
}

class RecoveryBackupProtectionException implements Exception {
  const RecoveryBackupProtectionException(this.message);

  final String message;

  @override
  String toString() => 'RecoveryBackupProtectionException: $message';
}

abstract class RecoveryBackupProtector {
  const RecoveryBackupProtector();

  Future<void> protectFile(String filePath);

  static RecoveryBackupProtector createDefault() {
    return Platform.isIOS
        ? const _IOSRecoveryBackupProtector()
        : const _NoOpRecoveryBackupProtector();
  }
}

class _NoOpRecoveryBackupProtector extends RecoveryBackupProtector {
  const _NoOpRecoveryBackupProtector();

  @override
  Future<void> protectFile(String filePath) async {}
}

class _IOSRecoveryBackupProtector extends RecoveryBackupProtector {
  const _IOSRecoveryBackupProtector();

  static const MethodChannel _channel = MethodChannel(
    'recovery_companion/recovery_backup_protector',
  );

  @override
  Future<void> protectFile(String filePath) async {
    final normalizedPath = filePath.trim();

    if (normalizedPath.isEmpty) {
      throw const RecoveryBackupProtectionException(
        'Recovery file path is missing.',
      );
    }

    try {
      final result = await _channel.invokeMethod<bool>('excludeFromBackup', {
        'path': normalizedPath,
      });

      if (result != true) {
        throw const RecoveryBackupProtectionException(
          'Recovery file backup exclusion was not applied.',
        );
      }
    } on PlatformException catch (error) {
      throw RecoveryBackupProtectionException(
        'Recovery file backup exclusion failed: '
        '${error.message ?? 'unknown platform error'}',
      );
    } on RecoveryBackupProtectionException {
      rethrow;
    } catch (_) {
      throw const RecoveryBackupProtectionException(
        'Recovery file backup exclusion failed unexpectedly.',
      );
    }
  }
}
