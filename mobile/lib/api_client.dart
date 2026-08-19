import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.apiToken = '',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String apiToken;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getHealth() async {
    return _getJson(
      '/health',
      authenticated: false,
    );
  }

  Future<Map<String, dynamic>> getRecoveryInsights() async {
    return _getJson(
      '/recovery-insights',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> getGoals() async {
    return _getJson(
      '/goals',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> getRoutines() async {
    return _getJson(
      '/routines',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> getTodayCheckin() async {
    return _getJson(
      '/daily-checkin/today',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> getJournalEntries() async {
    return _getJson(
      '/journal',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> searchJournal(
    String query,
  ) async {
    final encodedQuery = Uri.encodeQueryComponent(
      query,
    );

    return _getJson(
      '/journal/search?q=$encodedQuery',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> createJournalEntry({
    required String text,
    required List<String> tags,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/journal'),
      headers: {
        ...authenticatedHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'tags': tags,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'API request failed.',
        statusCode: response.statusCode,
      );
    }

    return _decodeJsonObject(
      response.body,
    );
  }

  Future<Map<String, dynamic>> saveTodayCheckin({
    required bool prayerMeditation,
    required bool recoveryContact,
    required bool meeting,
    required bool stepWork,
    required bool journal,
    required bool service,
    required String note,
  }) async {
    final response = await _httpClient.put(
      Uri.parse('$baseUrl/daily-checkin/today'),
      headers: {
        ...authenticatedHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'prayer_meditation': prayerMeditation,
        'recovery_contact': recoveryContact,
        'meeting': meeting,
        'step_work': stepWork,
        'journal': journal,
        'service': service,
        'note': note,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'API request failed.',
        statusCode: response.statusCode,
      );
    }

    return _decodeJsonObject(
      response.body,
    );
  }

  Map<String, String> get authenticatedHeaders {
    if (apiToken.isEmpty) {
      return const {};
    }

    return {
      'Authorization': 'Bearer $apiToken',
    };
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    required bool authenticated,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: authenticated
          ? authenticatedHeaders
          : const {},
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'API request failed.',
        statusCode: response.statusCode,
      );
    }

    return _decodeJsonObject(
      response.body,
    );
  }

  Map<String, dynamic> _decodeJsonObject(
    String body,
  ) {
    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        'API returned an unexpected response.',
      );
    }

    return decoded;
  }

  void close() {
    _httpClient.close();
  }
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return '$message HTTP $statusCode';
  }
}