import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signing recovery runbook documents safe recovery', () {
    final runbook = File('../docs/android-release-signing-recovery.md')
        .readAsStringSync();

    expect(runbook, contains('com.recoverycompanionlabs.recoverycompanion'));

    expect(runbook, contains('recovery-companion-upload'));

    expect(
      runbook,
      contains('must be stored separately in a password manager'),
    );

    expect(runbook, contains('must not be stored in this repository'));

    expect(runbook, contains('Do not copy a password value'));
  });

  test('recovery runbook contains no credential assignments', () {
    final runbook = File('../docs/android-release-signing-recovery.md')
        .readAsStringSync();

    final credentialAssignment = RegExp(
      r'^\s*(storePassword|keyPassword)\s*=',
      multiLine: true,
    );

    expect(credentialAssignment.hasMatch(runbook), isFalse);
  });
}
