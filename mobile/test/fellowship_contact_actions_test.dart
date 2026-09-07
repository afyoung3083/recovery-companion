import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/fellowship_contact_actions.dart';

class RecordingLauncher {
  RecordingLauncher({this.result = true, this.throwError = false});

  final bool result;
  final bool throwError;
  final List<Uri> requested = [];

  Future<bool> call(Uri uri) async {
    requested.add(uri);

    if (throwError) {
      throw StateError('Simulated platform launch failure');
    }

    return result;
  }
}

void main() {
  test('call produces expected tel URI', () async {
    final launcher = RecordingLauncher();
    final actions = FellowshipContactActions(launcher: launcher.call);

    final launched = await actions.call('555-0100');

    expect(launched, isTrue);
    expect(launcher.requested, [Uri.parse('tel:555-0100')]);
  });

  test('text produces expected sms URI', () async {
    final launcher = RecordingLauncher();
    final actions = FellowshipContactActions(launcher: launcher.call);

    final launched = await actions.text('555-0100');

    expect(launched, isTrue);
    expect(launcher.requested, [Uri.parse('sms:555-0100')]);
  });

  test('email produces expected mailto URI', () async {
    final launcher = RecordingLauncher();
    final actions = FellowshipContactActions(launcher: launcher.call);

    final launched = await actions.email('sponsor@example.test');

    expect(launched, isTrue);
    expect(launcher.requested, [Uri.parse('mailto:sponsor@example.test')]);
  });

  test('surrounding whitespace is trimmed', () async {
    final launcher = RecordingLauncher();
    final actions = FellowshipContactActions(launcher: launcher.call);

    await actions.call('  555-0100  ');

    expect(launcher.requested, [Uri.parse('tel:555-0100')]);
  });

  test('empty input does not launch', () async {
    final launcher = RecordingLauncher();
    final actions = FellowshipContactActions(launcher: launcher.call);

    final launched = await actions.call('   ');

    expect(launched, isFalse);
    expect(launcher.requested, isEmpty);
  });

  test('launch returning false is surfaced safely', () async {
    final launcher = RecordingLauncher(result: false);
    final actions = FellowshipContactActions(launcher: launcher.call);

    final launched = await actions.email('sponsor@example.test');

    expect(launched, isFalse);
  });

  test('launch throwing is surfaced safely as failure', () async {
    final launcher = RecordingLauncher(throwError: true);
    final actions = FellowshipContactActions(launcher: launcher.call);

    final launched = await actions.text('555-0100');

    expect(launched, isFalse);
  });
}
