class MobileConfig {
  const MobileConfig._();

  // Keep synchronized with mobile/pubspec.yaml.
  // A regression test protects against version drift.
  static const String betaBuildLabel = '1.21.0+6';

  static const String privacyPolicyUrl =
      'https://afyoung3083.github.io/recovery-companion/privacy/';

  static const String supportEmail = 'support@recoverycompanionlabs.com';

  static const String apiBaseUrl = String.fromEnvironment(
    'RECOVERY_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String apiToken = String.fromEnvironment(
    'RECOVERY_API_TOKEN',
    defaultValue: '',
  );
}
