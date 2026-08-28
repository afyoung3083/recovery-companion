import 'package:flutter/foundation.dart';

import 'secure_offline_cache_store.dart';

class OnboardingStore {
  OnboardingStore({SecureKeyValueStore? storage})
    : _storage = storage ?? FlutterSecureKeyValueStore();

  static const String completionKey =
      'recovery_companion.onboarding_complete.v1';

  /// Lets the active OnboardingGate respond when another screen
  /// resets or completes onboarding through a separate store instance.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  final SecureKeyValueStore _storage;

  Future<bool> isComplete() async {
    return await _storage.read(key: completionKey) == 'true';
  }

  Future<void> markComplete() async {
    await _storage.write(key: completionKey, value: 'true');

    changes.value++;
  }

  Future<void> reset() async {
    await _storage.delete(key: completionKey);

    changes.value++;
  }
}
