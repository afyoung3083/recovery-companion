import 'package:url_launcher/url_launcher.dart' as url_launcher;

/// Injectable launch function so widget tests never invoke real platform intents.
typedef ContactUrlLauncher = Future<bool> Function(Uri uri);

/// Opens native call/text/email composers for a Fellowship contact.
///
/// This never places a call or sends a message on the user's behalf; it only
/// hands off to the device's own dialer, SMS composer, or email client.
class FellowshipContactActions {
  const FellowshipContactActions({ContactUrlLauncher? launcher})
    : _launcher = launcher ?? _defaultLaunch;

  final ContactUrlLauncher _launcher;

  static Future<bool> _defaultLaunch(Uri uri) {
    return url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );
  }

  Future<bool> call(String phone) => _launch(scheme: 'tel', value: phone);

  Future<bool> text(String phone) => _launch(scheme: 'sms', value: phone);

  Future<bool> email(String email) => _launch(scheme: 'mailto', value: email);

  Future<bool> _launch({required String scheme, required String value}) async {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return false;
    }

    final Uri uri;
    try {
      uri = Uri.parse('$scheme:$trimmed');
    } on FormatException {
      return false;
    }

    try {
      return await _launcher(uri);
    } catch (_) {
      return false;
    }
  }
}
