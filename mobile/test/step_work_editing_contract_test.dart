import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Step Work UI exposes reversible completion and editing', () {
    final screen = File('lib/step_work_screen.dart').readAsStringSync();

    expect(screen, contains('Checkbox('));

    expect(screen, contains("'step-work-completed-\$id'"));

    expect(screen, contains("'step-work-edit-\$id'"));

    expect(screen, contains("'Edit Assignment'"));

    expect(screen, contains('Mark assignment incomplete'));

    expect(screen, isNot(contains('Icons.radio_button_unchecked')));
  });
}
