import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Dashboard provides sparse-data first-use guidance', () {
    final dashboard = source('lib/dashboard_screen.dart');

    expect(dashboard, contains("'dashboard-first-use-guidance'"));

    expect(dashboard, contains('showFirstUseGuidance'));

    expect(dashboard, contains("title: 'Start here'"));

    expect(dashboard, contains("label: 'Daily Recovery'"));
  });

  test('More provides a discoverable new-user orientation card', () {
    final more = source('lib/more_screen.dart');

    expect(more, contains("'more-new-user-guidance'"));

    expect(more, contains("title: 'New here?'"));

    expect(more, contains("label: 'Fellowship'"));

    expect(more, contains("label: 'Reminders'"));
  });
}
