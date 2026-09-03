import 'package:flutter/material.dart';

import 'ai_service_error.dart';
import 'api_client.dart';
import 'app_components.dart';
import 'local_weekly_review_repository.dart';

class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({
    required this.apiClient,
    this.localRepository,
    super.key,
  });

  final ApiClient apiClient;
  final LocalWeeklyReviewRepository? localRepository;

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
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
        : widget.apiClient.getCurrentWeeklyReview();
    _historyFuture = widget.localRepository != null
        ? widget.localRepository!.getHistory()
        : widget.apiClient.getWeeklyReviewHistory();
    _comparisonFuture = widget.localRepository != null
        ? widget.localRepository!.getComparison()
        : widget.apiClient.getWeeklyReviewComparison();
  }

  void _reloadAll({bool clearReflection = false}) {
    setState(() {
      _error = null;

      if (clearReflection) {
        _reflection = null;
      }

      _currentFuture = widget.localRepository != null
          ? widget.localRepository!.getCurrentReview()
          : widget.apiClient.getCurrentWeeklyReview();

      _historyFuture = widget.localRepository != null
          ? widget.localRepository!.getHistory()
          : widget.apiClient.getWeeklyReviewHistory();

      _comparisonFuture = widget.localRepository != null
          ? widget.localRepository!.getComparison()
          : widget.apiClient.getWeeklyReviewComparison();
    });
  }

  Future<void> _refresh() async {
    final current = widget.localRepository != null
        ? widget.localRepository!.getCurrentReview()
        : widget.apiClient.getCurrentWeeklyReview();

    final history = widget.localRepository != null
        ? widget.localRepository!.getHistory()
        : widget.apiClient.getWeeklyReviewHistory();

    final comparison = widget.localRepository != null
        ? widget.localRepository!.getComparison()
        : widget.apiClient.getWeeklyReviewComparison();

    setState(() {
      _error = null;
      _currentFuture = current;
      _historyFuture = history;
      _comparisonFuture = comparison;
    });

    try {
      await Future.wait([current, history, comparison]);
    } catch (_) {
      // Individual sections present their own safe
      // loading errors.
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
        await widget.apiClient.saveWeeklyReviewSnapshot();
      }

      if (!mounted) {
        return;
      }

      _reloadAll(clearReflection: true);

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Weekly review saved.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to save this weekly review. Please try again.';
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
      final localRepository = widget.localRepository;

      late final Map<String, dynamic> response;

      if (localRepository != null) {
        final payload = await localRepository.buildAiReflectionPayload();

        final summary = (payload['summary'] ?? '').toString().trim();

        if (summary.isEmpty) {
          throw StateError('No local Weekly Review summary is available.');
        }

        response = await widget.apiClient.getWeeklyReviewAiReflection(
          summary: summary,
        );
      } else {
        response = await widget.apiClient.getWeeklyReviewAiReflection();
      }

      if (!mounted) {
        return;
      }

      final reflection = (response['reflection'] ?? '').toString().trim();

      setState(() {
        _reflection = reflection.isEmpty
            ? 'No reflection was returned.'
            : reflection;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = aiServiceErrorMessage(error);
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
        key: const ValueKey('weekly-review-screen'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const AppPageHeader(
            title: 'Weekly Review',
            subtitle: 'Notice what happened over the past seven days without turning recovery into a score.',
            icon: Icons.calendar_view_week_outlined,
          ),

          const AppSectionTitle(
            title: 'Save This Week',
            subtitle: 'Create a snapshot you can look back on later.',
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
                        'Saving a snapshot records the current seven-day review in your history.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('weekly-review-save'),
                    onPressed: busy ? null : _saveSnapshot,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Weekly Snapshot'),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            AppStatusMessage(
              title: 'Weekly Review action unavailable',
              message: _error!,
              icon: Icons.error_outline,
            ),
          ],

          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'Current Review',
            subtitle: 'A summary of the recovery activity currently recorded for this week.',
          ),

          _TextFutureCard(
            future: _currentFuture,
            responseKey: 'review',
            emptyMessage: 'No weekly review is available yet.',
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
                        'AI reflection only runs when you explicitly request it. '
                        'Only the locally constructed Weekly Review summary is sent.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('weekly-review-ai-button'),
                    onPressed: busy ? null : _generateAiReflection,
                    icon: _reflecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_alt_outlined),
                    label: Text(
                      _reflecting ? 'Reflecting...' : 'Reflect with AI',
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_reflection != null) ...[
            const SizedBox(height: 16),
            AppSectionCard(
              key: const ValueKey('weekly-review-ai-reflection'),
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
            subtitle: 'Recent snapshots of your weekly recovery activity.',
          ),

          _WeeklyHistoryCard(future: _historyFuture),

          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'Latest Comparison',
            subtitle: 'Look for patterns between saved weeks without judging the result.',
          ),

          _TextFutureCard(
            future: _comparisonFuture,
            responseKey: 'comparison',
            emptyMessage: 'Save at least two weekly reviews to compare them.',
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

class _WeeklyHistoryCard extends StatelessWidget {
  const _WeeklyHistoryCard({required this.future});

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
            title: 'Unable to load weekly history',
            message: 'Recovery Companion could not load saved weekly reviews. Pull down to try again.',
            icon: Icons.cloud_off_outlined,
          );
        }

        final rawHistory = snapshot.data?['history'];

        final history = rawHistory is List
            ? rawHistory.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];

        if (history.isEmpty) {
          return const AppStatusMessage(
            title: 'No saved weekly reviews yet',
            message: 'Save a weekly snapshot when you want to begin building a history.',
            icon: Icons.history_outlined,
          );
        }

        final recent = history.reversed.take(5).toList();

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
    final start = (item['week_start'] ?? '?').toString();

    final end = (item['week_end'] ?? '?').toString();

    final checkinDays = item['checkin_days'] ?? 0;

    final journalEntries = item['journal_entries'] ?? 0;

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.calendar_today_outlined)),
      title: Text('$start to $end'),
      subtitle: Text(
        '$checkinDays check-in days '
        '\u2022 $journalEntries journal entries',
      ),
    );
  }
}
