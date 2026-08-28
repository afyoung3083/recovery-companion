import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Play health declaration uses behavioral health category', () {
    final health = File('../docs/google-play-health-declaration-final.md')
        .readAsStringSync();

    expect(health, contains('Mental and Behavioral Health'));

    expect(health, contains('not a medical device'));

    expect(health, contains('not an emergency'));
  });

  test('Play store listing preserves recovery-support boundaries', () {
    final listing = File('../docs/google-play-store-listing.md')
        .readAsStringSync();

    expect(listing, contains('local-first'));

    expect(listing, contains('AI is optional'));

    expect(listing, contains('not a medical device'));

    expect(listing, contains('not an emergency or crisis-response service'));
  });

  test('App Content package documents ads audience and rating', () {
    final appContent = File('../docs/google-play-app-content-declarations.md')
        .readAsStringSync();

    expect(appContent, contains('No, Recovery Companion does not contain ads'));

    expect(appContent, contains('Adults'));

    expect(appContent, contains('IARC'));
  });
}
