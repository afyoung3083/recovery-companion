import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

class _PngInfo {
  const _PngInfo({
    required this.width,
    required this.height,
    required this.colorType,
  });

  final int width;
  final int height;
  final int colorType;

  bool get isOpaqueRgb => colorType == 2;
}

_PngInfo _readPngInfo(File file) {
  final bytes = file.readAsBytesSync();
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

  expect(bytes.length, greaterThanOrEqualTo(26));
  expect(bytes.sublist(0, 8), signature);
  expect(utf8.decode(bytes.sublist(12, 16)), 'IHDR');

  final data = ByteData.sublistView(Uint8List.fromList(bytes));

  return _PngInfo(
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: bytes[25],
  );
}

void _expectPng(File file, int width, int height) {
  expect(file.existsSync(), isTrue, reason: file.path);
  final info = _readPngInfo(file);

  expect(info.width, width, reason: file.path);
  expect(info.height, height, reason: file.path);
  expect(info.isOpaqueRgb, isTrue, reason: file.path);
}

void main() {
  test('beta branding assets match platform contracts', () {
    final master = File('assets/branding/recovery_companion_master.jpg');
    final squareMaster = File(
      'assets/branding/recovery_companion_master_square_beta.png',
    );

    expect(master.existsSync(), isTrue);
    expect(master.lengthSync(), greaterThan(0));
    _expectPng(squareMaster, 146, 146);

    const androidIcons = <String, List<int>>{
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': [48, 48],
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': [72, 72],
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': [96, 96],
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': [144, 144],
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': [192, 192],
    };

    for (final entry in androidIcons.entries) {
      _expectPng(File(entry.key), entry.value[0], entry.value[1]);
    }

    final appIconDirectory = Directory(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    );
    final contents = jsonDecode(
      File('${appIconDirectory.path}/Contents.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final images = contents['images'] as List<dynamic>;
    var marketingIconFound = false;

    for (final rawImage in images) {
      final image = rawImage as Map<String, dynamic>;
      final filename = image['filename'] as String?;
      if (filename == null) {
        continue;
      }

      final size = (image['size'] as String).split('x');
      final scale = int.parse((image['scale'] as String).replaceFirst('x', ''));
      final width = (double.parse(size[0]) * scale).round();
      final height = (double.parse(size[1]) * scale).round();

      _expectPng(File('${appIconDirectory.path}/$filename'), width, height);

      if (image['idiom'] == 'ios-marketing') {
        marketingIconFound = true;
        expect(width, 1024);
        expect(height, 1024);
      }
    }

    expect(marketingIconFound, isTrue);

    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final androidGradle = File('android/app/build.gradle.kts')
        .readAsStringSync();
    final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();

    expect(infoPlist, contains('<string>Recovery Companion</string>'));
    expect(
      androidGradle,
      contains('applicationId = "com.recoverycompanionlabs.recoverycompanion"'),
    );
    expect(
      pbxproj,
      contains(
        'PRODUCT_BUNDLE_IDENTIFIER = com.recoverycompanionlabs.recoverycompanion;',
      ),
    );
  });
}
