class MobileConfig {
  const MobileConfig._();

  // Keep synchronized with mobile/pubspec.yaml.
  // A regression test protects against version drift.
  static const String betaBuildLabel = '1.22.0+8';

  static const String privacyPolicyUrl =
      'https://afyoung3083.github.io/recovery-companion/privacy/';

  static const String supportEmail = 'support@recoverycompanionlabs.com';

  static const String productionApiBaseUrl =
      'https://api.recoverycompanionlabs.com';

  // Production is the safe default for distributed builds.
  //
  // Developers may override this at build/run time with:
  // --dart-define=RECOVERY_API_BASE_URL=<development URL>
  static const String apiBaseUrl = String.fromEnvironment(
    'RECOVERY_API_BASE_URL',
    defaultValue: productionApiBaseUrl,
  );

  // Temporary closed-beta bearer credential.
  //
  // The value must never be committed to source control. It is supplied
  // only at build time through a local ignored dart-define file.
  static const String apiToken = String.fromEnvironment(
    'RECOVERY_API_TOKEN',
    defaultValue: '',
  );

  static bool get hasApiToken => apiToken.trim().isNotEmpty;
}
