import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Data Safety evidence stays conservative about provider retention', () {
    final evidence = File('../docs/google-play-data-safety-evidence.md')
        .readAsStringSync();

    expect(evidence, contains('store=False'));

    expect(
      evidence,
      contains('Do not classify Recovery Companion AI processing as ephemeral'),
    );

    expect(evidence, contains('Sharing'));

    expect(evidence, contains('production API hostname'));
  });
}
