import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_insights_repository.dart';
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
  late LocalInsightsRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'local_insights_repository_test_',
    );

    store = LocalRecoveryStore(
      dataFile: File(
        '${directory.path}'
        '${Platform.pathSeparator}'
        'recovery_data.enc',
      ),
      keyStore: MemorySecureKeyValueStore(),
    );

    repository = LocalInsightsRepository(
      store: store,
      now: () => DateTime(2026, 8, 27, 12),
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('builds safe empty insights', () async {
    final result = await repository.getInsights();

    final insights = result['recovery_insights_data'] as Map;

    expect(insights['sobriety_days'], isNull);

    expect(insights['current_step'], 1);

    expect(insights['open_step_assignments'], 0);

    expect(insights['active_recovery_goals'], 0);

    expect(insights['checkin_days_available'], 0);
  });

  test('builds recovery metrics locally', () async {
    await store.write({
      'profile': {'sobriety_date': '2026-08-12'},
      'step_work': {
        'current_step': 4,
        'assignments': [
          {'id': 1, 'step': 4, 'completed': false},
          {'id': 2, 'step': 4, 'completed': true},
          {'id': 3, 'step': 5, 'completed': false},
        ],
      },
      'goals': [
        {'id': 1, 'active': true},
        {'id': 2, 'active': false},
        {'id': 3, 'active': true},
      ],
      'daily_checkins': {
        '2026-08-27': {},
        '2026-08-25': {},
        '2026-08-21': {},
        '2026-08-01': {},
      },
    });

    final result = await repository.getInsights();

    final insights = result['recovery_insights_data'] as Map;

    expect(insights['sobriety_days'], 15);

    expect(insights['current_step'], 4);

    expect(insights['open_step_assignments'], 1);

    expect(insights['active_recovery_goals'], 2);

    expect(insights['checkin_days_available'], 3);
  });

  test('uses latest weekly and monthly snapshots', () async {
    await store.write({
      'weekly_reviews': [
        {'week_end': '2026-08-20', 'checkin_days': 3},
        {'week_end': '2026-08-27', 'checkin_days': 5},
      ],
      'monthly_reviews': [
        {'snapshot_date': '2026-07-31', 'checkin_days': 10},
        {'snapshot_date': '2026-08-27', 'checkin_days': 18},
      ],
    });

    final result = await repository.getInsights();

    final insights = result['recovery_insights_data'] as Map;

    expect(
      (insights['latest_weekly_snapshot'] as Map)['week_end'],
      '2026-08-27',
    );

    expect(
      (insights['latest_monthly_snapshot'] as Map)['snapshot_date'],
      '2026-08-27',
    );
  });

  test('insights do not expose raw journal or notes', () async {
    await store.write({
      'journal_entries': [
        {'id': 1, 'text': 'Very private journal text'},
      ],
      'daily_checkins': {
        '2026-08-27': {'note': 'Very private check-in note'},
      },
    });

    final result = await repository.getInsights();

    final encoded = result.toString();

    expect(encoded, isNot(contains('Very private journal text')));

    expect(encoded, isNot(contains('Very private check-in note')));
  });

  test('underlying recovery data remains encrypted', () async {
    await store.write({
      'journal_entries': [
        {'id': 1, 'text': 'Encrypted insight source'},
      ],
    });

    await repository.getInsights();

    final encrypted = await store.dataFile.readAsString();

    expect(encrypted, isNot(contains('Encrypted insight source')));
  });
}
