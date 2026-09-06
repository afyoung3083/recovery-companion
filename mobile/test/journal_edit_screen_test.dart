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
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<Map<String, String>> readAll() async => {};

  @override
  Future<void> write({required String key, required String value}) async {}
}

class FakeLocalJournalRepository extends LocalJournalRepository {
  FakeLocalJournalRepository({this.failUpdates = false})
    : _entries = [
        {
          'id': 7,
          'created_at': '2026-09-03T14:30:00Z',
          'date': '2026-09-03',
          'text': 'Original journal entry.',
          'tags': ['connection'],
          'unknown_field': 'preserved',
        },
      ],
      super(
        store: LocalRecoveryStore(
          dataFile: File('unused-journal-edit-widget-test.enc'),
          keyStore: MemorySecureKeyValueStore(),
        ),
      );

  final bool failUpdates;
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
  Future<Map<String, dynamic>> search(String query) async => getEntries();

  @override
  Future<Map<String, dynamic>> createEntry({
    required String text,
    required List<String> tags,
  }) async {
    final entry = {
      'id': 8,
      'created_at': '2026-09-06T12:00:00Z',
      'date': '2026-09-06',
      'text': text,
      'tags': List<String>.from(tags),
    };
    _entries.add(entry);
    return {'entry': Map<String, dynamic>.from(entry)};
  }

  @override
  Future<Map<String, dynamic>> updateEntry({
    required int entryId,
    required String text,
    required List<String> tags,
  }) async {
    if (failUpdates) {
      throw StateError('Update failed');
    }

    final index = _entries.indexWhere((entry) => entry['id'] == entryId);
    if (index < 0) {
      throw StateError('Journal entry $entryId was not found.');
    }

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

Future<void> pumpJournal(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> scrollUntilVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 16; attempt++) {
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

ApiClient testApiClient({http.Client? client}) {
  return ApiClient(
    baseUrl: 'http://example.test',
    apiToken: 'test-token',
    httpClient: client ?? MockClient((_) async => http.Response('{}', 500)),
  );
}

void main() {
  testWidgets('local entry exposes Edit and loads text and tags separately', (
    tester,
  ) async {
    final repository = FakeLocalJournalRepository();
    final apiClient = testApiClient();
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
    await pumpJournal(tester);

    final editButton = find.byKey(const ValueKey('journal-edit-7'));
    await scrollUntilVisible(tester, editButton);
    expect(find.byKey(const ValueKey('journal-ai-7')), findsOneWidget);

    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Edit Journal Entry'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('journal-edit-text')))
          .controller
          ?.text,
      'Original journal entry.',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('journal-edit-tags')))
          .controller
          ?.text,
      'connection',
    );
  });

  testWidgets('saving edits updates local Journal text and tags', (
    tester,
  ) async {
    final repository = FakeLocalJournalRepository();
    final apiClient = testApiClient();
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
    await pumpJournal(tester);
    await scrollUntilVisible(
      tester,
      find.byKey(const ValueKey('journal-edit-7')),
    );
    await tester.tap(find.byKey(const ValueKey('journal-edit-7')));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const ValueKey('journal-edit-text')),
      'Edited journal entry.',
    );
    await tester.enterText(
      find.byKey(const ValueKey('journal-edit-tags')),
      'honesty, sponsor',
    );
    tester.testTextInput.hide();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('journal-edit-save')));
    await pumpJournal(tester);

    expect(find.text('Journal entry updated.'), findsOneWidget);
    expect(find.text('Edited journal entry.'), findsOneWidget);
    expect(find.text('honesty'), findsOneWidget);
    expect(find.text('sponsor'), findsOneWidget);
    expect(find.text('Original journal entry.'), findsNothing);

    final saved = repository._entries.single;
    expect(saved['id'], 7);
    expect(saved['created_at'], '2026-09-03T14:30:00Z');
    expect(saved['date'], '2026-09-03');
  });

  testWidgets('cancel leaves the original Journal entry unchanged', (
    tester,
  ) async {
    final repository = FakeLocalJournalRepository();
    final apiClient = testApiClient();
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
    await pumpJournal(tester);
    await scrollUntilVisible(
      tester,
      find.byKey(const ValueKey('journal-edit-7')),
    );
    await tester.tap(find.byKey(const ValueKey('journal-edit-7')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('journal-edit-text')),
      'Unsaved change',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Edit Journal Entry'), findsNothing);
    expect(find.text('Original journal entry.'), findsOneWidget);
    expect(repository._entries.single['text'], 'Original journal entry.');
  });

  testWidgets('edit failure keeps the editor open with an error', (
    tester,
  ) async {
    final repository = FakeLocalJournalRepository(failUpdates: true);
    final apiClient = testApiClient();
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
    await pumpJournal(tester);
    await scrollUntilVisible(
      tester,
      find.byKey(const ValueKey('journal-edit-7')),
    );
    await tester.tap(find.byKey(const ValueKey('journal-edit-7')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('journal-edit-text')),
      'Retry this edit',
    );
    await tester.tap(find.byKey(const ValueKey('journal-edit-save')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Edit Journal Entry'), findsOneWidget);
    expect(
      find.text('Unable to update this journal entry. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('journal-edit-text')))
          .controller
          ?.text,
      'Retry this edit',
    );
  });

  testWidgets('non-local Journal remains readable without an Edit action', (
    tester,
  ) async {
    final apiClient = testApiClient(
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/journal') {
          return http.Response(
            '{"entries":[{"id":7,"date":"2026-09-03","text":"Remote entry","tags":[]}]}',
            200,
          );
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: JournalScreen(apiClient: apiClient)),
      ),
    );
    await pumpJournal(tester);
    await scrollUntilVisible(tester, find.text('Remote entry'));

    expect(find.byKey(const ValueKey('journal-edit-7')), findsNothing);
    expect(find.byKey(const ValueKey('journal-ai-7')), findsOneWidget);
  });

  testWidgets('existing New Entry workflow remains available locally', (
    tester,
  ) async {
    final repository = FakeLocalJournalRepository();
    final apiClient = testApiClient();
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
    await pumpJournal(tester);

    final composer = find.byKey(const ValueKey('journal-entry-composer'));
    expect(composer, findsOneWidget);
    final fields = find.descendant(
      of: composer,
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'A new journal entry.');
    await tester.tap(find.byKey(const ValueKey('journal-save-entry')));
    await pumpJournal(tester);

    expect(find.text('Journal entry saved.'), findsOneWidget);
    await scrollUntilVisible(tester, find.text('A new journal entry.'));
    expect(find.text('A new journal entry.'), findsOneWidget);
  });
}
