import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS production identity and config are locked to the app bundle', () {
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    final appBundleConfig =
        'PRODUCT_BUNDLE_IDENTIFIER = com.recoverycompanionlabs.recoverycompanion;';
    final staleAppBundleConfig =
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.mobile;';

    expect(pbxproj, contains(appBundleConfig));
    expect(pbxproj, isNot(contains(staleAppBundleConfig)));

    expect(infoPlist, contains('<string>Recovery Companion</string>'));
    expect(infoPlist, contains('<key>CFBundleDisplayName</key>'));
    expect(infoPlist, contains('<key>CFBundleShortVersionString</key>'));
    expect(infoPlist, contains('<key>CFBundleVersion</key>'));
    expect(infoPlist, contains('<string>\$(FLUTTER_BUILD_NAME)</string>'));
    expect(infoPlist, contains('<string>\$(FLUTTER_BUILD_NUMBER)</string>'));

    expect(pbxproj, contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'));
    expect(pbxproj, contains('TARGETED_DEVICE_FAMILY = "1,2";'));
  });
}
