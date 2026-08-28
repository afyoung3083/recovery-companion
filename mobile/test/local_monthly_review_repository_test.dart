import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_monthly_review_repository.dart';
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

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_monthly_review_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}'
        '${Platform.pathSeparator}'
        'recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('current review is empty without weekly snapshots', () async {
    final repository = LocalMonthlyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    final result = await repository.getCurrentReview();

    expect(result['review'], '');
  });

  test('builds current review from up to four recent weeks', () async {
    await store.write({
      'weekly_reviews': [
        {
          'week_start': '2026-07-24',
          'week_end': '2026-07-30',
          'checkin_days': 1,
          'journal_entries': 1,
        },
        {
          'week_start': '2026-07-31',
          'week_end': '2026-08-06',
          'checkin_days': 2,
          'journal_entries': 1,
        },
        {
          'week_start': '2026-08-07',
          'week_end': '2026-08-13',
          'checkin_days': 3,
          'journal_entries': 2,
        },
        {
          'week_start': '2026-08-14',
          'week_end': '2026-08-20',
          'checkin_days': 4,
          'journal_entries': 2,
        },
        {
          'week_start': '2026-08-21',
          'week_end': '2026-08-27',
          'checkin_days': 5,
          'journal_entries': 3,
        },
      ],
    });

    final repository = LocalMonthlyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    final result = await repository.getCurrentReview();

    final snapshot = result['snapshot'] as Map;

    expect(snapshot['weekly_reviews_included'], 4);

    expect(snapshot['period_start'], '2026-07-31');

    expect(snapshot['period_end'], '2026-08-27');

    expect(snapshot['checkin_days'], 14);

    expect(snapshot['journal_entries'], 8);
  });

  test('saves and reloads monthly snapshot', () async {
    await store.write({
      'weekly_reviews': [
        {
          'week_start': '2026-08-21',
          'week_end': '2026-08-27',
          'checkin_days': 5,
          'journal_entries': 3,
        },
      ],
    });

    final repository = LocalMonthlyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    await repository.saveSnapshot();

    final result = await repository.getHistory();

    final history = result['history'] as List;

    expect(history.length, 1);

    expect((history.first as Map)['snapshot_date'], '2026-08-27');

    expect((history.first as Map)['weekly_reviews_included'], 1);
  });

  test('compares two monthly snapshots', () async {
    await store.write({
      'weekly_reviews': [
        {
          'week_start': '2026-07-24',
          'week_end': '2026-07-30',
          'checkin_days': 2,
          'journal_entries': 1,
        },
      ],
    });

    final first = LocalMonthlyReviewRepository(
      store: store,
      now: () => DateTime(2026, 7, 30, 12),
    );

    await first.saveSnapshot();

    final document = await store.read();

    final data = Map<String, dynamic>.from(document['data'] as Map);

    data['weekly_reviews'] = [
      {
        'week_start': '2026-08-21',
        'week_end': '2026-08-27',
        'checkin_days': 4,
        'journal_entries': 3,
      },
    ];

    await store.write(data);

    final second = LocalMonthlyReviewRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );

    await second.saveSnapshot();

    final result = await second.getComparison();

    expect(result['comparison'].toString(), contains('+2 check-in days'));

    expect(result['comparison'].toString(), contains('+2 journal entries'));
  });

  test(
    'monthly snapshot remains encrypted and preserves recovery data',
    () async {
      await store.write({
        'profile': {'sobriety_date': '2026-08-12'},
        'journal_entries': [
          {'id': 1, 'text': 'Private monthly text'},
        ],
        'weekly_reviews': [
          {
            'week_start': '2026-08-21',
            'week_end': '2026-08-27',
            'checkin_days': 5,
            'journal_entries': 3,
          },
        ],
      });

      final repository = LocalMonthlyReviewRepository(
        store: store,
        now: () => DateTime(2026, 8, 27, 12),
      );

      await repository.saveSnapshot();

      final encrypted = await store.dataFile.readAsString();

      expect(encrypted, isNot(contains('Private monthly text')));

      final document = await store.read();

      final data = Map<String, dynamic>.from(document['data'] as Map);

      expect((data['profile'] as Map)['sobriety_date'], '2026-08-12');

      expect(data['monthly_reviews'], isA<List>());
    },
  );
}
