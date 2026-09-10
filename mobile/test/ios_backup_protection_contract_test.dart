import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS backup protection does not disclose recovery file paths', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('recovery_companion/recovery_backup_protector'));
    expect(source, contains('excludeFromBackup'));
    expect(source, contains('code: "FILE_NOT_FOUND"'));
    expect(source, contains('message: "Recovery file does not exist."'));
    expect(source, contains('details: nil'));
    expect(source, isNot(contains('details: fileURL.path')));
    expect(source, isNot(contains('details: rawPath')));
  });
}
