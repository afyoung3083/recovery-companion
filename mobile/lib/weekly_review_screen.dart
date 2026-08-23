import 'package:flutter/material.dart';

import 'api_client.dart';

class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<WeeklyReviewScreen> createState() =>
      _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  late Future<Map<String, dynamic>> _currentFuture;
  late Future<Map<String, dynamic>> _historyFuture;
  late Future<Map<String, dynamic>> _comparisonFuture;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _error = null;
      _currentFuture =
          widget.apiClient.getCurrentWeeklyReview();
      _historyFuture =
          widget.apiClient.getWeeklyReviewHistory();
      _comparisonFuture =
          widget.apiClient.getWeeklyReviewComparison();
    });
  }

  Future<void> _saveSnapshot() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.apiClient.saveWeeklyReviewSnapshot();

      if (!mounted) {
        return;
      }

      _loadAll();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Weekly review saved.',
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Weekly Review',
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Review the past seven days and save a snapshot of your recovery activity.',
        ),
        const SizedBox(height: 20),

        FilledButton.icon(
          onPressed: _saving
              ? null
              : _saveSnapshot,
          icon: const Icon(
            Icons.save_outlined,
          ),
          label: Text(
            _saving
                ? 'Saving...'
                : 'Save Weekly Snapshot',
          ),
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
                      ? 'No weekly review available.'
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
                    'No saved weekly reviews yet.',
                  ),
                ),
              );
            }

            final recent =
                history.reversed.take(5).toList();

            return Column(
              children: recent
                  .map(
                    (item) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.calendar_view_week_outlined,
                        ),
                        title: Text(
                          '${item['week_start'] ?? '?'} '
                          'to ${item['week_end'] ?? '?'}',
                        ),
                        subtitle: Text(
                          'Check-In Days: '
                          '${item['checkin_days'] ?? 0}/7\n'
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
          onPressed: _saving
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