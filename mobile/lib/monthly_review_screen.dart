import 'package:flutter/material.dart';

import 'api_client.dart';

class MonthlyReviewScreen extends StatefulWidget {
  const MonthlyReviewScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<MonthlyReviewScreen> createState() =>
      _MonthlyReviewScreenState();
}

class _MonthlyReviewScreenState extends State<MonthlyReviewScreen> {
  late Future<Map<String, dynamic>> _currentFuture;
  late Future<Map<String, dynamic>> _historyFuture;
  late Future<Map<String, dynamic>> _comparisonFuture;

  bool _saving = false;
  bool _reflecting = false;
  String? _error;
  String? _reflection;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _error = null;
      _reflection = null;

      _currentFuture =
          widget.apiClient.getCurrentMonthlyReview();

      _historyFuture =
          widget.apiClient.getMonthlyReviewHistory();

      _comparisonFuture =
          widget.apiClient.getMonthlyReviewComparison();
    });
  }

  Future<void> _saveSnapshot() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.apiClient.saveMonthlyReviewSnapshot();

      if (!mounted) {
        return;
      }

      _loadAll();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Monthly review saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _generateAiReflection() async {
    setState(() {
      _reflecting = true;
      _error = null;
      _reflection = null;
    });

    try {
      final response =
          await widget.apiClient.getMonthlyReviewAiReflection();

      if (!mounted) {
        return;
      }

      final reflection = (
        response['reflection'] ??
        ''
      ).toString();

      setState(() {
        _reflection = reflection.isEmpty
            ? 'No AI reflection was returned.'
            : reflection;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _reflecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _reflecting;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Monthly Review',
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Review your most recent saved weekly recovery snapshots as a rolling four-week summary.',
        ),
        const SizedBox(height: 20),

        FilledButton.icon(
          onPressed: busy
              ? null
              : _saveSnapshot,
          icon: const Icon(
            Icons.save_outlined,
          ),
          label: Text(
            _saving
                ? 'Saving...'
                : 'Save Monthly Snapshot',
          ),
        ),

        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: busy
              ? null
              : _generateAiReflection,
          icon: const Icon(
            Icons.auto_awesome_outlined,
          ),
          label: Text(
            _reflecting
                ? 'Generating Reflection...'
                : 'Generate AI Reflection',
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'AI Reflection is optional and only runs when you request it.',
          textAlign: TextAlign.center,
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .error,
            ),
          ),
        ],

        if (_reflection != null) ...[
          const SizedBox(height: 28),

          Text(
            'AI Reflection',
            style: Theme.of(context)
                .textTheme
                .titleLarge,
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _reflection!,
              ),
            ),
          ),
        ],

        const SizedBox(height: 28),

        Text(
          'Current Review',
          style: Theme.of(context)
              .textTheme
              .titleLarge,
        ),
        const SizedBox(height: 12),

        FutureBuilder<Map<String, dynamic>>(
          future: _currentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                snapshot.error.toString(),
              );
            }

            final review = (
              snapshot.data?['review'] ??
              ''
            ).toString();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  review.isEmpty
                      ? 'No monthly review available.'
                      : review,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 28),

        Text(
          'Saved History',
          style: Theme.of(context)
              .textTheme
              .titleLarge,
        ),
        const SizedBox(height: 12),

        FutureBuilder<Map<String, dynamic>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                snapshot.error.toString(),
              );
            }

            final rawHistory =
                snapshot.data?['history'];

            final history = rawHistory is List
                ? rawHistory
                    .whereType<Map<String, dynamic>>()
                    .toList()
                : <Map<String, dynamic>>[];

            if (history.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No saved monthly reviews yet.',
                  ),
                ),
              );
            }

            final recent =
                history.reversed.take(6).toList();

            return Column(
              children: recent
                  .map(
                    (item) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.calendar_month_outlined,
                        ),
                        title: Text(
                          'Snapshot: '
                          '${item['snapshot_date'] ?? '?'}',
                        ),
                        subtitle: Text(
                          'Period: '
                          '${item['period_start'] ?? '?'} '
                          'to ${item['period_end'] ?? '?'}\n'
                          'Weekly Reviews: '
                          '${item['weekly_reviews_included'] ?? 0}/4\n'
                          'Check-In Days: '
                          '${item['checkin_days'] ?? 0}\n'
                          'Journal Entries: '
                          '${item['journal_entries'] ?? 0}',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),

        const SizedBox(height: 28),

        Text(
          'Latest Comparison',
          style: Theme.of(context)
              .textTheme
              .titleLarge,
        ),
        const SizedBox(height: 12),

        FutureBuilder<Map<String, dynamic>>(
          future: _comparisonFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                snapshot.error.toString(),
              );
            }

            final comparison = (
              snapshot.data?['comparison'] ??
              ''
            ).toString();

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  comparison.isEmpty
                      ? 'No comparison available.'
                      : comparison,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        OutlinedButton.icon(
          onPressed: busy
              ? null
              : _loadAll,
          icon: const Icon(
            Icons.refresh,
          ),
          label: const Text(
            'Refresh',
          ),
        ),
      ],
    );
  }
}