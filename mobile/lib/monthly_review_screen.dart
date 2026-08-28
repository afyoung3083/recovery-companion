import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'local_monthly_review_repository.dart';

class MonthlyReviewScreen extends StatefulWidget {
  const MonthlyReviewScreen({
    required this.apiClient,
    this.localRepository,
    super.key,
  });

  final ApiClient apiClient;
  final LocalMonthlyReviewRepository? localRepository;

  @override
  State<MonthlyReviewScreen> createState() => _MonthlyReviewScreenState();
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

    _currentFuture = widget.localRepository != null
        ? widget.localRepository!.getCurrentReview()
        : widget.apiClient.getCurrentMonthlyReview();
    _historyFuture = widget.localRepository != null
        ? widget.localRepository!.getHistory()
        : widget.apiClient.getMonthlyReviewHistory();
    _comparisonFuture = widget.localRepository != null
        ? widget.localRepository!.getComparison()
        : widget.apiClient.getMonthlyReviewComparison();
  }

  void _reloadAll({bool clearReflection = false}) {
    setState(() {
      _error = null;

      if (clearReflection) {
        _reflection = null;
      }

      _currentFuture = widget.localRepository != null
          ? widget.localRepository!.getCurrentReview()
          : widget.apiClient.getCurrentMonthlyReview();

      _historyFuture = widget.localRepository != null
          ? widget.localRepository!.getHistory()
          : widget.apiClient.getMonthlyReviewHistory();

      _comparisonFuture = widget.localRepository != null
          ? widget.localRepository!.getComparison()
          : widget.apiClient.getMonthlyReviewComparison();
    });
  }

  Future<void> _refresh() async {
    final current = widget.localRepository != null
        ? widget.localRepository!.getCurrentReview()
        : widget.apiClient.getCurrentMonthlyReview();

    final history = widget.localRepository != null
        ? widget.localRepository!.getHistory()
        : widget.apiClient.getMonthlyReviewHistory();

    final comparison = widget.localRepository != null
        ? widget.localRepository!.getComparison()
        : widget.apiClient.getMonthlyReviewComparison();

    setState(() {
      _error = null;
      _currentFuture = current;
      _historyFuture = history;
      _comparisonFuture = comparison;
    });

    try {
      await Future.wait([current, history, comparison]);
    } catch (_) {
      // Individual sections show their own safe errors.
    }
  }

  Future<void> _saveSnapshot() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.saveSnapshot();
      } else {
        await widget.apiClient.saveMonthlyReviewSnapshot();
      }

      if (!mounted) {
        return;
      }

      _reloadAll(clearReflection: true);

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Monthly review saved.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to save this monthly review. Make sure at least one weekly snapshot has been saved, then try again.';
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
      final response = await widget.apiClient.getMonthlyReviewAiReflection();

      if (!mounted) {
        return;
      }

      final reflection = (response['reflection'] ?? '').toString().trim();

      setState(() {
        _reflection = reflection.isEmpty
            ? 'No reflection was returned.'
            : reflection;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error =
            'Unable to generate an AI reflection right now. Please try again.';
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

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const ValueKey('monthly-review-screen'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const AppPageHeader(
            title: 'Monthly Review',
            subtitle: 'Notice patterns across your most recent saved weeks without turning recovery into a score.',
            icon: Icons.calendar_month_outlined,
          ),

          const AppSectionTitle(
            title: 'Save This Period',
            subtitle: 'Create a rolling four-week snapshot from your saved weekly reviews.',
          ),

          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bookmark_outline),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Monthly Review is built from up to your four most recent saved weekly snapshots.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('monthly-review-save'),
                    onPressed: busy ? null : _saveSnapshot,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Monthly Snapshot',
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            AppStatusMessage(
              title: 'Monthly Review action unavailable',
              message: _error!,
              icon: Icons.error_outline,
            ),
          ],

          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'Current Review',
            subtitle: 'A rolling summary built from your most recent saved weekly reviews.',
          ),

          _TextFutureCard(
            future: _currentFuture,
            responseKey: 'review',
            emptyMessage: 'No monthly review is available yet.',
            errorTitle: 'Unable to load current review',
          ),

          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'Optional AI Reflection',
            subtitle: 'AI is available as a reflection aid, not as a replacement for your sponsor, fellowship, therapist, clergy, or Higher Power.',
          ),

          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI reflection only runs when you explicitly request it.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('monthly-review-ai-button'),
                    onPressed: busy || widget.localRepository != null
                        ? null
                        : _generateAiReflection,
                    icon: _reflecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_alt_outlined),
                    label: Text(
                      widget.localRepository != null
                          ? 'AI Reflection Requires Sync'
                          : _reflecting
                          ? 'Reflecting...'
                          : 'Reflect with AI',
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_reflection != null) ...[
            const SizedBox(height: 16),
            AppSectionCard(
              key: const ValueKey('monthly-review-ai-reflection'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Reflection',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(_reflection!),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'Saved History',
            subtitle: 'Recent rolling four-week snapshots.',
          ),

          _MonthlyHistoryCard(future: _historyFuture),

          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'Latest Comparison',
            subtitle: 'Compare saved snapshots neutrally and look for patterns rather than grades.',
          ),

          _TextFutureCard(
            future: _comparisonFuture,
            responseKey: 'comparison',
            emptyMessage: 'Save at least two monthly reviews to compare them.',
            errorTitle: 'Unable to load comparison',
          ),
        ],
      ),
    );
  }
}

class _TextFutureCard extends StatelessWidget {
  const _TextFutureCard({
    required this.future,
    required this.responseKey,
    required this.emptyMessage,
    required this.errorTitle,
  });

  final Future<Map<String, dynamic>> future;
  final String responseKey;
  final String emptyMessage;
  final String errorTitle;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppSectionCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return AppStatusMessage(
            title: errorTitle,
            message: 'Recovery Companion could not load this section. Pull down to try again.',
            icon: Icons.cloud_off_outlined,
          );
        }

        final text = (snapshot.data?[responseKey] ?? '').toString().trim();

        return AppSectionCard(
          child: SelectableText(text.isEmpty ? emptyMessage : text),
        );
      },
    );
  }
}

class _MonthlyHistoryCard extends StatelessWidget {
  const _MonthlyHistoryCard({required this.future});

  final Future<Map<String, dynamic>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppSectionCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const AppStatusMessage(
            title: 'Unable to load monthly history',
            message: 'Recovery Companion could not load saved monthly reviews. Pull down to try again.',
            icon: Icons.cloud_off_outlined,
          );
        }

        final rawHistory = snapshot.data?['history'];

        final history = rawHistory is List
            ? rawHistory.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];

        if (history.isEmpty) {
          return const AppStatusMessage(
            title: 'No saved monthly reviews yet',
            message: 'Save a monthly snapshot when you want to begin building a history.',
            icon: Icons.history_outlined,
          );
        }

        final recent = history.reversed.take(6).toList();

        return AppSectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var index = 0; index < recent.length; index++) ...[
                _HistoryTile(item: recent[index]),
                if (index < recent.length - 1)
                  const Divider(height: 1, indent: 68),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final snapshotDate = (item['snapshot_date'] ?? '?').toString();

    final periodStart = (item['period_start'] ?? '?').toString();

    final periodEnd = (item['period_end'] ?? '?').toString();

    final weeklyReviews = item['weekly_reviews_included'] ?? 0;

    final checkinDays = item['checkin_days'] ?? 0;

    final journalEntries = item['journal_entries'] ?? 0;

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.calendar_month_outlined)),
      title: Text('Snapshot $snapshotDate'),
      subtitle: Text(
        '$periodStart to $periodEnd\n'
        '$weeklyReviews/4 weekly reviews '
        '\u2022 $checkinDays check-in days '
        '\u2022 $journalEntries journal entries',
      ),
    );
  }
}
