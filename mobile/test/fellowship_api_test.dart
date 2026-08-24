import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/api_client.dart';

void main() {
  const baseUrl = 'http://example.test';
  const token = 'test-token';

  test('getFellowshipContacts sends authenticated GET', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), '$baseUrl/fellowship');
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      return http.Response(
        jsonEncode({
          'count': 1,
          'contacts': [
            {
              'id': 1,
              'handle': 'Mike',
              'contact_type': 'sponsor',
              'active': true,
            },
          ],
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final response =
        await apiClient.getFellowshipContacts();

    expect(response['count'], 1);

    final contacts = response['contacts'] as List<dynamic>;
    expect(contacts.first['handle'], 'Mike');

    apiClient.close();
  });

  test(
    'getRecommendedFellowshipContacts sends limit and auth',
    () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          '$baseUrl/fellowship/recommended?limit=5',
        );
        expect(
          request.headers['Authorization'],
          'Bearer $token',
        );

        return http.Response(
          jsonEncode({
            'count': 0,
            'contacts': [],
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: baseUrl,
        apiToken: token,
        httpClient: mockClient,
      );

      final response =
          await apiClient.getRecommendedFellowshipContacts(
        limit: 5,
      );

      expect(response['count'], 0);

      apiClient.close();
    },
  );

  test('createFellowshipContact sends expected JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), '$baseUrl/fellowship');
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      final body =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['handle'], 'John');
      expect(body['contact_type'], 'fellowship');
      expect(body['contact_method'], '555-0200');
      expect(body['notes'], 'Thursday meeting');

      return http.Response(
        jsonEncode({
          'contact': {
            'id': 2,
            'handle': 'John',
            'contact_type': 'fellowship',
            'contact_method': '555-0200',
            'notes': 'Thursday meeting',
            'active': true,
          },
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final response =
        await apiClient.createFellowshipContact(
      handle: 'John',
      contactType: 'fellowship',
      contactMethod: '555-0200',
      notes: 'Thursday meeting',
    );

    expect(response['contact']['id'], 2);

    apiClient.close();
  });

  test('setFellowshipContactActive sends expected JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        '$baseUrl/fellowship/2/active',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      final body =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['active'], false);

      return http.Response(
        jsonEncode({
          'contact': {
            'id': 2,
            'handle': 'John',
            'contact_type': 'fellowship',
            'active': false,
          },
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final response =
        await apiClient.setFellowshipContactActive(
      contactId: 2,
      active: false,
    );

    expect(response['contact']['active'], false);

    apiClient.close();
  });

  test('updateFellowshipContact sends expected JSON', () async {
    final mockClient = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        '$baseUrl/fellowship/2',
      );
      expect(
        request.headers['Authorization'],
        'Bearer $token',
      );

      final body =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(body['handle'], 'Sponsor Bob');
      expect(body['contact_type'], 'sponsor');
      expect(body['contact_method'], '555-0100');
      expect(body['notes'], 'Call when isolating.');

      return http.Response(
        jsonEncode({
          'contact': {
            'id': 2,
            'handle': 'Sponsor Bob',
            'contact_type': 'sponsor',
            'contact_method': '555-0100',
            'notes': 'Call when isolating.',
            'active': true,
          },
        }),
        200,
      );
    });

    final apiClient = ApiClient(
      baseUrl: baseUrl,
      apiToken: token,
      httpClient: mockClient,
    );

    final response =
        await apiClient.updateFellowshipContact(
      contactId: 2,
      handle: 'Sponsor Bob',
      contactType: 'sponsor',
      contactMethod: '555-0100',
      notes: 'Call when isolating.',
    );

    expect(
      response['contact']['handle'],
      'Sponsor Bob',
    );

    apiClient.close();
  });
}