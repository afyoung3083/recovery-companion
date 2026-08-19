class MobileConfig {
  const MobileConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'RECOVERY_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String apiToken = String.fromEnvironment(
    'RECOVERY_API_TOKEN',
    defaultValue: '',
  );
}