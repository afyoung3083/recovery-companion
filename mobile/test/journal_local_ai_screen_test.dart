import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api_client.dart';
import 'package:mobile/app_theme.dart';
import 'package:mobile/journal_screen.dart';
import 'package:mobile/local_journal_repository.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<Map<String, String>> readAll() async =>
      Map<String, String>.from(values);

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class FakeLocalJournalRepository extends LocalJournalRepository {
  FakeLocalJournalRepository()
    : _entries = [
        {
          'id': 1,
          'created_at': '2026-09-03T14:30:00Z',
          'date': '2026-09-03',
          'text': 'I isolated after work.',
          'tags': ['isolation'],
        },
      ],
      super(
        store: LocalRecoveryStore(
          dataFile: File('unused-journal-test.enc'),
          keyStore: MemorySecureKeyValueStore(),
        ),
      );

  final List<Map<String, dynamic>> _entries;

  @override
  Future<Map<String, dynamic>> getEntries() async {
    return {
      'entries': _entries
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> getEntryForAiReflection(int entryId) async {
    expect(entryId, 1);
    final entry = _entries.singleWhere((entry) => entry['id'] == entryId);
    return {'entry_id': 1, 'text': entry['text']};
  }

  @override
  Future<Map<String, dynamic>> updateEntry({
    required int entryId,
    required String text,
    required List<String> tags,
  }) async {
    final index = _entries.indexWhere((entry) => entry['id'] == entryId);
    final updated = {
      ..._entries[index],
      'text': text,
      'tags': List<String>.from(tags),
      'updated_at': '2026-09-06T12:30:00Z',
    };
    _entries[index] = updated;
    return {'entry': Map<String, dynamic>.from(updated)};
  }
}

Future<void> scrollUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 15; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  throw TestFailure('Expected Journal widget did not become visible.');
}

void main() {
  testWidgets('local-first journal entry can be reflected with AI', (
    tester,
  ) async {
    final repository = FakeLocalJournalRepository();
    var aiRequestCount = 0;

    final mockClient = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/journal/1/ai-reflection') {
        aiRequestCount += 1;

        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['text'], 'I isolated after work.');

        return http.Response(
          jsonEncode({
            'entry_id': 1,
            'reflection': 'You chose connection instead of isolation.',
          }),
          200,
        );
      }

      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: mockClient,
    );

    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: JournalScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final analyzeButton = find.byKey(const ValueKey('journal-ai-1'));
    await scrollUntilVisible(tester, analyzeButton);

    final button = tester.widget<OutlinedButton>(analyzeButton);
    expect(button.onPressed, isNotNull);

    await tester.tap(analyzeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(aiRequestCount, 0);
    expect(find.text('Analyze this journal entry?'), findsOneWidget);

    await tester.tap(find.text('Analyze Entry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(aiRequestCount, 1);
    expect(
      find.text('You chose connection instead of isolation.'),
      findsOneWidget,
    );
  });

  testWidgets('edited local Journal text is sent for later AI reflection', (
    tester,
  ) async {
    final repository = FakeLocalJournalRepository();
    var aiRequestCount = 0;
    Map<String, dynamic>? requestBody;

    final mockClient = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/journal/1/ai-reflection') {
        aiRequestCount += 1;
        expect(request.headers['Authorization'], 'Bearer test-token');
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'entry_id': 1,
            'reflection': 'You chose connection after work.',
          }),
          200,
        );
      }

      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });

    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      apiToken: 'test-token',
      httpClient: mockClient,
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: JournalScreen(
            apiClient: apiClient,
            localRepository: repository,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final editButton = find.byKey(const ValueKey('journal-edit-1'));
    await scrollUntilVisible(tester, editButton);
    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('journal-edit-text')),
      'I called my sponsor after work instead of isolating.',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('journal-edit-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('I called my sponsor after work instead of isolating.'),
      findsOneWidget,
    );

    final analyzeButton = find.byKey(const ValueKey('journal-ai-1'));
    await scrollUntilVisible(tester, analyzeButton);
    await tester.tap(analyzeButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Analyze this journal entry?'), findsOneWidget);
    expect(aiRequestCount, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(aiRequestCount, 0);

    await tester.tap(analyzeButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Analyze Entry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(aiRequestCount, 1);
    expect(requestBody, {
      'text': 'I called my sponsor after work instead of isolating.',
    });
    expect(requestBody.toString(), isNot(contains('I isolated after work.')));
    expect(find.text('You chose connection after work.'), findsOneWidget);
  });
}
