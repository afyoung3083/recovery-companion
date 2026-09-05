import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_client.dart';

const String _localDataReminder =
    'Your saved recovery data remains available on this device.';

String aiServiceErrorMessage(Object error) {
  if (error is ApiException) {
    final statusCode = error.statusCode;

    if (statusCode == 401 || statusCode == 403) {
      return 'AI access could not be authorized for this beta build. '
          'Update Recovery Companion to the latest beta build or use '
          'Beta Feedback & Support. $_localDataReminder';
    }

    if (statusCode == 413) {
      return 'That AI request is too large. Try a shorter selection. '
          '$_localDataReminder';
    }

    if (statusCode == 422) {
      return 'Recovery Companion could not prepare that AI request. '
          'Please try again. $_localDataReminder';
    }

    if (statusCode == 429) {
      return 'AI is temporarily busy. Wait a minute and try again. '
          '$_localDataReminder';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'AI is temporarily unavailable. '
          '$_localDataReminder Please try again later.';
    }
  }

  if (error is SocketException ||
      error is HandshakeException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return 'Recovery Companion could not reach the AI service. '
        'Check your internet connection and try again. '
        '$_localDataReminder';
  }

  return 'AI is unavailable right now. '
      '$_localDataReminder Please try again.';
}
