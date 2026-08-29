import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closed beta operations use external tester membership', () {
    final operations = File('../docs/google-play-closed-test-operations.md')
        .readAsStringSync();

    expect(operations, contains('Use a dedicated Google Group'));

    expect(
      operations,
      contains(
        'Do not place individual tester email addresses in repository files',
      ),
    );

    expect(operations, contains('version code'));

    expect(operations, contains('tester opt-in'));
  });

  test('tester invitation protects recovery privacy', () {
    final invitation = File('../docs/closed-beta-tester-invitation-template.md')
        .readAsStringSync();

    expect(invitation, contains('Closed Beta Tester Guide'));

    expect(invitation, contains('Beta Feedback & Support'));

    expect(invitation, contains('avoid including private journal entries'));
  });

  test('tester roster policy prohibits identities in git', () {
    final roster = File('../docs/closed-beta-roster-policy.md')
        .readAsStringSync();

    expect(roster, contains('Do not commit tester names'));

    expect(roster, contains('Tester membership is administered'));

    expect(roster, contains('Source code changes are not required'));
  });
}
