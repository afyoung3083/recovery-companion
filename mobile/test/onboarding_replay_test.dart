import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/onboarding_store.dart';
import 'package:mobile/secure_offline_cache_store.dart';
import 'package:mobile/settings_privacy_screen.dart';

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
  testWidgets('Settings can reset onboarding', (tester) async {
    final onboardingStore = OnboardingStore(
      storage: MemorySecureKeyValueStore(),
    );

    await onboardingStore.markComplete();

    expect(await onboardingStore.isComplete(), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPrivacyScreen(
          apiClient: ApiClient(baseUrl: 'http://example.invalid'),
          onboardingStore: onboardingStore,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final replay = find.byKey(const ValueKey('replay-onboarding'));

    // Settings is a lazy ListView, so the button may not
    // exist until we scroll far enough to build it.
    await tester.scrollUntilVisible(
      replay,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(replay, findsOneWidget);

    await tester.tap(replay);
    await tester.pumpAndSettle();

    final confirm = find.byKey(const ValueKey('confirm-replay-onboarding'));

    expect(confirm, findsOneWidget);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(await onboardingStore.isComplete(), isFalse);
  });
}
