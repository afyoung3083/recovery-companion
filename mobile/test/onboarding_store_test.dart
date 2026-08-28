import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/onboarding_store.dart';
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
  test('onboarding starts incomplete and can be completed', () async {
    final storage = MemorySecureKeyValueStore();

    final store = OnboardingStore(storage: storage);

    expect(await store.isComplete(), isFalse);

    await store.markComplete();

    expect(await store.isComplete(), isTrue);
  });

  test('onboarding can be reset independently', () async {
    final storage = MemorySecureKeyValueStore();

    final store = OnboardingStore(storage: storage);

    await store.markComplete();
    await store.reset();

    expect(await store.isComplete(), isFalse);
  });
}
