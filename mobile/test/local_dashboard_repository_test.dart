import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_dashboard_repository.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/secure_offline_cache_store.dart';

class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<Map<String, String>> readAll() async {
    return Map<String, String>.from(values);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

void main() {
  late Directory directory;
  late LocalRecoveryStore store;
  late LocalDashboardRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_dashboard_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}'
        '${Platform.pathSeparator}'
        'recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    repository = LocalDashboardRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('builds empty local dashboard safely', () async {
    final result = await repository.getDashboard();

    final dashboard = result['dashboard_data'] as Map;

    expect(dashboard['sobriety_days'], isNull);

    expect(dashboard['current_step'], 1);

    expect(dashboard['open_assignments'], isEmpty);

    expect(dashboard['recommended_contacts'], isEmpty);
  });

  test('calculates sobriety and today check-in', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'daily_checkins': {
        '2026-08-27': {
          'prayer_meditation': true,
          'recovery_contact': true,
          'meeting': false,
          'step_work': true,
          'journal': false,
          'service': true,
          'note': 'Stay connected.',
        },
      },
    });

    final result = await repository.getDashboard();

    final dashboard = result['dashboard_data'] as Map;

    expect(dashboard['sobriety_days'], 15);

    final checkin = dashboard['today_checkin'] as Map;

    expect(checkin['saved'], isTrue);

    expect(checkin['completed_count'], 4);

    expect(checkin['total'], 6);

    expect(checkin['note'], 'Stay connected.');
  });

  test('shows only open assignments for current Step', () async {
    await store.write({
      'step_work': {
        'current_step': 4,
        'assignments': [
          {'id': 1, 'step': 4, 'text': 'Open Step 4', 'completed': false},
          {'id': 2, 'step': 4, 'text': 'Completed Step 4', 'completed': true},
          {'id': 3, 'step': 5, 'text': 'Open Step 5', 'completed': false},
        ],
      },
    });

    final result = await repository.getDashboard();

    final dashboard = result['dashboard_data'] as Map;

    expect(dashboard['current_step'], 4);

    final assignments = dashboard['open_assignments'] as List;

    expect(assignments.length, 1);

    expect((assignments.first as Map)['text'], 'Open Step 4');
  });

  test('uses latest journal and active fellowship contacts', () async {
    await store.write({
      'journal_entries': [
        {'id': 1, 'text': 'Older entry', 'created_at': '2026-08-25T10:00:00Z'},
        {'id': 2, 'text': 'Newest entry', 'created_at': '2026-08-27T10:00:00Z'},
      ],
      'fellowship_contacts': [
        {'id': 1, 'handle': 'Sponsor', 'active': true},
        {'id': 2, 'handle': 'Inactive', 'active': false},
        {'id': 3, 'handle': 'Friend', 'active': true},
      ],
    });

    final result = await repository.getDashboard();

    final dashboard = result['dashboard_data'] as Map;

    expect((dashboard['latest_journal_entry'] as Map)['text'], 'Newest entry');

    final contacts = dashboard['recommended_contacts'] as List;

    expect(contacts.length, 2);

    expect(contacts.map((item) => (item as Map)['handle']).toList(), [
      'Sponsor',
      'Friend',
    ]);
  });

  test('dashboard source data remains encrypted', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'journal_entries': [
        {
          'id': 1,
          'text': 'Private dashboard journal text',
          'created_at': '2026-08-27T10:00:00Z',
        },
      ],
    });

    await repository.getDashboard();

    final encrypted = await store.dataFile.readAsString();

    expect(encrypted, isNot(contains('Private dashboard journal text')));
  });
}
