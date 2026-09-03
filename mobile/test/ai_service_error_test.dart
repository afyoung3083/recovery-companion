import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/ai_service_error.dart';
import 'package:mobile/api_client.dart';

void main() {
  test('authorization failures give beta-build guidance', () {
    final message = aiServiceErrorMessage(
      const ApiException(
        'Unauthorized',
        statusCode: 401,
      ),
    );

    expect(message, contains('beta build'));
    expect(message, contains('latest beta build'));
    expect(message, contains('saved recovery data'));
  });

  test('rate limiting asks the user to wait', () {
    final message = aiServiceErrorMessage(
      const ApiException(
        'Too many requests',
        statusCode: 429,
      ),
    );

    expect(message, contains('temporarily busy'));
    expect(message, contains('Wait a minute'));
    expect(message, contains('saved recovery data'));
  });

  test('provider failures do not expose internal details', () {
    final message = aiServiceErrorMessage(
      const ApiException(
        'Sensitive provider detail',
        statusCode: 502,
      ),
    );

    expect(message, contains('temporarily unavailable'));
    expect(message, contains('saved recovery data'));
    expect(message, isNot(contains('Sensitive provider detail')));
  });

  test('network failures provide connection guidance', () {
    final message = aiServiceErrorMessage(
      const SocketException('offline'),
    );

    expect(message, contains('could not reach the AI service'));
    expect(message, contains('internet connection'));
    expect(message, contains('saved recovery data'));
  });

  test('HTTP client failures use network guidance', () {
    final message = aiServiceErrorMessage(
      http.ClientException('connection failed'),
    );

    expect(message, contains('could not reach the AI service'));
    expect(message, isNot(contains('connection failed')));
  });

  test('timeouts use network guidance', () {
    final message = aiServiceErrorMessage(
      TimeoutException('timeout'),
    );

    expect(message, contains('could not reach the AI service'));
    expect(message, isNot(contains('timeout')));
  });

  test('oversized AI requests receive actionable guidance', () {
    final message = aiServiceErrorMessage(
      const ApiException(
        'Too large',
        statusCode: 413,
      ),
    );

    expect(message, contains('too large'));
    expect(message, contains('shorter selection'));
  });

  test('unknown failures remain generic and privacy safe', () {
    final message = aiServiceErrorMessage(
      StateError('private internal detail'),
    );

    expect(message, contains('AI is unavailable right now'));
    expect(message, contains('saved recovery data'));
    expect(message, isNot(contains('private internal detail')));
  });
}
