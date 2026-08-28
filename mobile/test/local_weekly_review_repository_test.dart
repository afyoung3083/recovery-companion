import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_recovery_store.dart';
import 'package:mobile/local_weekly_review_repository.dart';
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

void main() {
  late Directory directory;
  late LocalRecoveryStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_weekly_review_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}${Platform.pathSeparator}recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('builds current review from local recovery data', () async {
    await store.write({
      'daily_checkins': {
        '2026-08-27': {'meeting': true},
        '2026-08-25': {'meeting': false},
        '2026-08-10': {'meeting': true},
      },
      'journal_entries': [
        {'id': 1, 'date': '2026-08-26', 'text': 'This week'},
        {'id': 2, 'date': '2026-08-01', 'text': 'Old'},
      ],
      'goals': [
        {'id': 1, 'active': true},
        {'id': 2, 'active': false},
      ],
      'routines': [
        {'id': 1, 'active': true},
      ],
    });

    final repository = LocalWeeklyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    final result = await repository.getCurrentReview();
    final snapshot = result['snapshot'] as Map;

    expect(snapshot['week_start'], '2026-08-21');
    expect(snapshot['week_end'], '2026-08-27');
    expect(snapshot['checkin_days'], 2);
    expect(snapshot['journal_entries'], 1);
    expect(snapshot['active_goals'], 1);
    expect(snapshot['active_routines'], 1);
  });

  test('saves and reloads weekly snapshot', () async {
    final repository = LocalWeeklyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    await repository.saveSnapshot();

    final result = await repository.getHistory();
    final history = result['history'] as List;

    expect(history.length, 1);
    expect((history.first as Map)['week_end'], '2026-08-27');
  });

  test('saving same week updates rather than duplicates', () async {
    final repository = LocalWeeklyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    await repository.saveSnapshot();

    await store.write({
      ...(await store.read())['data'] as Map,
      'daily_checkins': {
        '2026-08-27': {'meeting': true},
      },
      'weekly_reviews': ((await repository.getHistory())['history'] as List),
    });

    await repository.saveSnapshot();

    final result = await repository.getHistory();

    expect((result['history'] as List).length, 1);
  });

  test('compares latest two saved weeks', () async {
    final first = LocalWeeklyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 20, 12),
    );

    await store.write({
      'daily_checkins': {
        '2026-08-20': {'meeting': true},
      },
    });

    await first.saveSnapshot();

    final second = LocalWeeklyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    data['daily_checkins'] = {
      '2026-08-27': {'meeting': true},
      '2026-08-26': {'meeting': true},
    };

    await store.write(data);

    await second.saveSnapshot();

    final comparison = await second.getComparison();

    expect(comparison['comparison'].toString(), contains('+1 check-in days'));
  });

  test('weekly snapshots remain encrypted and preserve other data', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'journal_entries': [
        {'id': 1, 'date': '2026-08-27', 'text': 'Private journal text'},
      ],
    });

    final repository = LocalWeeklyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    await repository.saveSnapshot();

    final encrypted = await store.dataFile.readAsString();

    expect(encrypted, isNot(contains('Private journal text')));

    final document = await store.read();
    final data = Map<String, dynamic>.from(document['data'] as Map);

    expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');

    expect(data['weekly_reviews'], isA<List>());
  });
}
