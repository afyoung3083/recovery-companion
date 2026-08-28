import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import 'secure_offline_cache_store.dart';

class LocalRecoveryStoreException implements Exception {
  const LocalRecoveryStoreException(this.message);

  final String message;

  @override
  String toString() => 'LocalRecoveryStoreException: $message';
}

class LocalRecoveryStoreCorruptedException extends LocalRecoveryStoreException {
  const LocalRecoveryStoreCorruptedException(super.message);
}

class LocalRecoveryStoreKeyUnavailableException
    extends LocalRecoveryStoreException {
  const LocalRecoveryStoreKeyUnavailableException(super.message);
}

/// Authoritative encrypted recovery-data storage for the local device.
///
/// Unlike the Sprint 50 offline cache, this data is not disposable.
/// Corrupt or unreadable data is therefore never silently deleted.
class LocalRecoveryStore {
  LocalRecoveryStore({
    required this.dataFile,
    required this.keyStore,
    Cipher? cipher,
  }) : _cipher = cipher ?? AesGcm.with256bits();

  static const int envelopeVersion = 1;
  static const int dataSchemaVersion = 1;

  static const String encryptionKeyName =
      'recovery_companion.local_data.encryption_key.v1';

  static const String defaultFileName = 'recovery_data.enc';

  final File dataFile;
  final SecureKeyValueStore keyStore;
  final Cipher _cipher;

  static Future<LocalRecoveryStore> openDefault() async {
    final directory = await getApplicationSupportDirectory();

    return LocalRecoveryStore(
      dataFile: File(
        '${directory.path}${Platform.pathSeparator}$defaultFileName',
      ),
      keyStore: FlutterSecureKeyValueStore(),
    );
  }

  Future<bool> get exists async => dataFile.exists();

  /// Reads the authoritative local recovery-data document.
  ///
  /// A device with no saved recovery data returns a new empty document.
  /// Existing data that cannot be authenticated or decoded throws instead
  /// of being removed or replaced.
  Future<Map<String, dynamic>> read() async {
    if (!await dataFile.exists()) {
      return _emptyDocument();
    }

    final encodedEnvelope = await dataFile.readAsString();

    final envelope = _decodeEnvelope(encodedEnvelope);
    final secretKey = await _loadExistingKey();

    try {
      final secretBox = SecretBox(
        base64Decode(_requireString(envelope, 'cipher_text')),
        nonce: base64Decode(_requireString(envelope, 'nonce')),
        mac: Mac(base64Decode(_requireString(envelope, 'mac'))),
      );

      final clearText = await _cipher.decrypt(secretBox, secretKey: secretKey);

      final decoded = jsonDecode(utf8.decode(clearText));

      if (decoded is! Map<String, dynamic>) {
        throw const LocalRecoveryStoreCorruptedException(
          'Recovery data is not a JSON object.',
        );
      }

      if (decoded['schema_version'] != dataSchemaVersion) {
        throw LocalRecoveryStoreCorruptedException(
          'Unsupported recovery-data schema version: '
          '${decoded['schema_version']}.',
        );
      }

      final payload = decoded['data'];

      if (payload is! Map) {
        throw const LocalRecoveryStoreCorruptedException(
          'Recovery data payload is invalid.',
        );
      }

      return {
        'schema_version': dataSchemaVersion,
        'updated_at': decoded['updated_at'],
        'data': Map<String, dynamic>.from(payload),
      };
    } on LocalRecoveryStoreException {
      rethrow;
    } catch (_) {
      throw const LocalRecoveryStoreCorruptedException(
        'Encrypted recovery data could not be authenticated or decoded.',
      );
    }
  }

  /// Atomically replaces the authoritative local recovery document as far as
  /// the host filesystem permits.
  ///
  /// The old file is retained as a temporary backup until the new encrypted
  /// file has successfully replaced it.
  Future<void> write(Map<String, dynamic> data) async {
    await dataFile.parent.create(recursive: true);

    final secretKey = await _loadOrCreateKey();

    final document = {
      'schema_version': dataSchemaVersion,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };

    final clearText = utf8.encode(jsonEncode(document));
    final nonce = _cipher.newNonce();

    final secretBox = await _cipher.encrypt(
      clearText,
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = jsonEncode({
      'envelope_version': envelopeVersion,
      'algorithm': 'AES-256-GCM',
      'nonce': base64Encode(secretBox.nonce),
      'cipher_text': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    });

    final tempFile = File('${dataFile.path}.tmp');
    final backupFile = File('${dataFile.path}.bak');

    await tempFile.writeAsString(envelope, flush: true);

    final hadExistingFile = await dataFile.exists();

    try {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      if (hadExistingFile) {
        await dataFile.rename(backupFile.path);
      }

      await tempFile.rename(dataFile.path);

      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (_) {
      if (!await dataFile.exists() && await backupFile.exists()) {
        await backupFile.rename(dataFile.path);
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      rethrow;
    }
  }

  /// Permanently removes this app's authoritative local recovery data and
  /// encryption key.
  Future<void> deleteAll() async {
    if (await dataFile.exists()) {
      await dataFile.delete();
    }

    final tempFile = File('${dataFile.path}.tmp');
    final backupFile = File('${dataFile.path}.bak');

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    if (await backupFile.exists()) {
      await backupFile.delete();
    }

    await keyStore.delete(key: encryptionKeyName);
  }

  Map<String, dynamic> _emptyDocument() {
    return {
      'schema_version': dataSchemaVersion,
      'updated_at': null,
      'data': <String, dynamic>{},
    };
  }

  Map<String, dynamic> _decodeEnvelope(String encoded) {
    try {
      final decoded = jsonDecode(encoded);

      if (decoded is! Map<String, dynamic>) {
        throw const LocalRecoveryStoreCorruptedException(
          'Encrypted recovery-data envelope is invalid.',
        );
      }

      if (decoded['envelope_version'] != envelopeVersion) {
        throw LocalRecoveryStoreCorruptedException(
          'Unsupported encrypted-data envelope version: '
          '${decoded['envelope_version']}.',
        );
      }

      return decoded;
    } on LocalRecoveryStoreException {
      rethrow;
    } catch (_) {
      throw const LocalRecoveryStoreCorruptedException(
        'Encrypted recovery-data envelope is malformed.',
      );
    }
  }

  String _requireString(Map<String, dynamic> source, String field) {
    final value = source[field];

    if (value is! String || value.isEmpty) {
      throw LocalRecoveryStoreCorruptedException(
        'Encrypted recovery-data field "$field" is missing.',
      );
    }

    return value;
  }

  Future<SecretKey> _loadExistingKey() async {
    final encoded = await keyStore.read(key: encryptionKeyName);

    if (encoded == null || encoded.isEmpty) {
      throw const LocalRecoveryStoreKeyUnavailableException(
        'Recovery data exists but its device encryption key is unavailable.',
      );
    }

    try {
      final bytes = base64Decode(encoded);

      if (bytes.length != 32) {
        throw const LocalRecoveryStoreKeyUnavailableException(
          'The device encryption key is invalid.',
        );
      }

      return SecretKey(bytes);
    } catch (error) {
      if (error is LocalRecoveryStoreException) {
        rethrow;
      }

      throw const LocalRecoveryStoreKeyUnavailableException(
        'The device encryption key could not be decoded.',
      );
    }
  }

  Future<SecretKey> _loadOrCreateKey() async {
    final existing = await keyStore.read(key: encryptionKeyName);

    if (existing != null && existing.isNotEmpty) {
      return _loadExistingKey();
    }

    // Never generate a replacement key over existing encrypted recovery data.
    if (await dataFile.exists()) {
      throw const LocalRecoveryStoreKeyUnavailableException(
        'Recovery data exists but its device encryption key is unavailable.',
      );
    }

    final secretKey = await _cipher.newSecretKey();
    final keyBytes = await secretKey.extractBytes();

    await keyStore.write(key: encryptionKeyName, value: base64Encode(keyBytes));

    return secretKey;
  }
}
