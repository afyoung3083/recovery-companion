import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/mobile_config.dart';

void main() {
  test('unsigned iOS preflight matches the current beta version', () {
    final preflight = File('../.github/workflows/ios-preflight.yml')
        .readAsStringSync();
    final parts = MobileConfig.betaBuildLabel.split('+');

    expect(parts, hasLength(2));
    expect(
      preflight,
      contains('[[ "\$marketing_version" == "${parts.first}" ]]'),
    );
    expect(preflight, contains('[[ "\$build_number" == "${parts.last}" ]]'));
  });

  final workflow = File('../.github/workflows/ios-signed-build.yml')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');

  test('signed iOS workflow supplies the beta credential at build time', () {
    expect(
      workflow,
      contains(r'RECOVERY_API_TOKEN: ${{ secrets.RECOVERY_API_TOKEN }}'),
    );
    expect(workflow, contains(r'--dart-define-from-file="$defines_path"'));
    expect(
      workflow,
      contains('json.dump({"RECOVERY_API_TOKEN": token}, handle)'),
    );
    expect(workflow, isNot(contains('secrets.OPENAI_API_KEY')));
  });

  test('signed iOS workflow guards and cleans temporary credentials', () {
    expect(workflow, contains('if len(token) < 32'));
    expect(workflow, contains('refusing to build.'));
    expect(workflow, contains('umask 077'));
    expect(workflow, contains('::add-mask::'));
    expect(workflow, contains('trap \'rm -f "\$defines_path"\' EXIT'));
  });

  test('beta label and signed iOS build number match pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    final version = match!.group(1)!;
    final parts = version.split('+');

    expect(parts, hasLength(2));
    expect(MobileConfig.betaBuildLabel, version);
    expect(
      workflow,
      contains('[[ "\$marketing_version" == "${parts.first}" ]]'),
    );
    expect(workflow, contains('[[ "\$build_number" == "${parts.last}" ]]'));
  });

  test(
    'signed IPA distribution remains tag-gated without public artifacts',
    () {
      expect(workflow, isNot(contains('actions/upload-artifact@')));
      expect(
        workflow,
        contains("if: startsWith(github.ref, 'refs/tags/ios-testflight-')"),
      );
    },
  );
}
