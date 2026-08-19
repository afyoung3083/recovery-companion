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

  // ============================================================
  // Public endpoints
  // ============================================================

  Future<Map<String, dynamic>> getHealth() async {
    return _getJson(
      '/health',
      authenticated: false,
    );
  }

  // ============================================================
  // Recovery data
  // ============================================================

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

  // ============================================================
  // Daily Check-In
  // ============================================================

  Future<Map<String, dynamic>> getTodayCheckin() async {
    return _getJson(
      '/daily-checkin/today',
      authenticated: true,
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
      Uri.parse(
        '$baseUrl/daily-checkin/today',
      ),
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

    return _handleJsonResponse(
      response,
    );
  }

  // ============================================================
  // Journal
  // ============================================================

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
      Uri.parse(
        '$baseUrl/journal',
      ),
      headers: {
        ...authenticatedHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'tags': tags,
      }),
    );

    return _handleJsonResponse(
      response,
    );
  }

  // ============================================================
  // Step Work
  // ============================================================

  Future<Map<String, dynamic>> getStepWork() async {
    return _getJson(
      '/step-work',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> setCurrentStep(
    int stepNumber,
  ) async {
    final response = await _httpClient.put(
      Uri.parse(
        '$baseUrl/step-work/current-step',
      ),
      headers: {
        ...authenticatedHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'step_number': stepNumber,
      }),
    );

    return _handleJsonResponse(
      response,
    );
  }

  Future<Map<String, dynamic>> createStepAssignment(
    String text,
  ) async {
    final response = await _httpClient.post(
      Uri.parse(
        '$baseUrl/step-work/assignments',
      ),
      headers: {
        ...authenticatedHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
      }),
    );

    return _handleJsonResponse(
      response,
    );
  }

  Future<Map<String, dynamic>> completeStepAssignment(
    int assignmentId,
  ) async {
    final response = await _httpClient.put(
      Uri.parse(
        '$baseUrl/step-work/assignments/'
        '$assignmentId/complete',
      ),
      headers: authenticatedHeaders,
    );

    return _handleJsonResponse(
      response,
    );
  }

  // ============================================================
  // Authentication
  // ============================================================

  Map<String, String> get authenticatedHeaders {
    if (apiToken.isEmpty) {
      return const {};
    }

    return {
      'Authorization': 'Bearer $apiToken',
    };
  }

  // ============================================================
  // HTTP helpers
  // ============================================================

  Future<Map<String, dynamic>> _getJson(
    String path, {
    required bool authenticated,
  }) async {
    final response = await _httpClient.get(
      Uri.parse(
        '$baseUrl$path',
      ),
      headers: authenticated
          ? authenticatedHeaders
          : const {},
    );

    return _handleJsonResponse(
      response,
    );
  }

  Map<String, dynamic> _handleJsonResponse(
    http.Response response,
  ) {
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
    final decoded = jsonDecode(
      body,
    );

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