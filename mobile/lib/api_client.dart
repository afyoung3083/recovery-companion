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
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/health'),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        'Health request failed.',
        statusCode: response.statusCode,
      );
    }

    return _decodeJsonObject(response.body);
  }

  Map<String, String> get authenticatedHeaders {
    if (apiToken.isEmpty) {
      return const {};
    }

    return {
      'Authorization': 'Bearer $apiToken',
    };
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
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