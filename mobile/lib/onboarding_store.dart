import 'secure_offline_cache_store.dart';

class OnboardingStore {
  OnboardingStore({SecureKeyValueStore? storage})
    : _storage = storage ?? FlutterSecureKeyValueStore();

  static const String completionKey =
      'recovery_companion.onboarding_complete.v1';

  final SecureKeyValueStore _storage;

  Future<bool> isComplete() async {
    return await _storage.read(key: completionKey) == 'true';
  }

  Future<void> markComplete() async {
    await _storage.write(key: completionKey, value: 'true');
  }

  Future<void> reset() async {
    await _storage.delete(key: completionKey);
  }
}
