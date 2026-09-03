import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distributed builds default to the production HTTPS API', () {
    final config = File('lib/mobile_config.dart').readAsStringSync();

    expect(
      config,
      contains(
        "'https://api.recoverycompanionlabs.com'",
      ),
    );

    expect(
      config,
      contains('defaultValue: productionApiBaseUrl'),
    );

    expect(
      config,
      isNot(
        contains(
          "defaultValue: 'http://10.0.2.2:8000'",
        ),
      ),
    );
  });

  test('beta API credential remains a build-time value', () {
    final config = File('lib/mobile_config.dart').readAsStringSync();

    expect(
      config,
      contains("'RECOVERY_API_TOKEN'"),
    );

    expect(
      config,
      contains("defaultValue: ''"),
    );
  });

  test('local production dart-define file is gitignored', () {
    final gitignore = File('../.gitignore').readAsStringSync();

    expect(
      gitignore,
      contains(
        'mobile/.dart-defines.production.json',
      ),
    );
  });
}
