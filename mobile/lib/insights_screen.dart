import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'offline_copy_notice.dart';
import 'offline_read_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({
    required this.apiClient,
    this.offlineReadService,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineReadService? offlineReadService;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  static const String _cacheKey = 'insights';

  late Future<OfflineReadResult> _insightsFuture;

  bool _analyzing = false;
  String? _aiError;
  String? _aiReflection;

  Future<OfflineReadResult> _loadInsights() async {
    final service = widget.offlineReadService;

    if (service == null) {
      final data = await widget.apiClient.getRecoveryInsights();

      return OfflineReadResult(
        data: data,
        source: OfflineReadSource.network,
      );
    }

    return service.read(
      cacheKey: _cacheKey,
      networkRead: widget.apiClient.getRecoveryInsights,
    );
  }

  @override
  void initState() {
    super.initState();
    _insightsFuture = _loadInsights();
  }

  void _refresh() {
    setState(() {
      _insightsFuture = _loadInsights();
    });
  }

  Future<void> _refreshAsync() async {
    final future = _loadInsights();

    setState(() {
      _insightsFuture = future;
    });

    await future;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    return const <String, dynamic>{};
  }

  Future<void> _analyzeRecoveryInsights() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Analyze Recovery Insights?'),
          content: const Text(
            'Recovery Companion will build your current Recovery '
            'Insights summary locally and send only that summary to '
            'the AI for an optional reflection. The summary contains '
            'dashboard counts and recovery status, not raw journal '
            'entries or check-in notes. The AI reflection is not '
            'saved automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Analyze Insights'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _analyzing = true;
      _aiError = null;
      _aiReflection = null;
    });

    try {
      final result =
          await widget.apiClient.getRecoveryInsightsAiReflection();

      if (!mounted) {
        return;
      }

      final reflection =
          (result['reflection'] ?? '').toString().trim();

      setState(() {
        _aiReflection = reflection.isEmpty
            ? 'No AI reflection was returned.'
            : reflection;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _aiError =
            'Unable to generate a Recovery Insights reflection. '
            'Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _analyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OfflineReadResult>(
      future: _insightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AppPageHeader(
                title: 'Recovery Insights',
                subtitle:
                    'A wider view of your recovery activity.',
                icon: Icons.insights_outlined,
              ),
              AppStatusMessage(
                title: 'Unable to load Recovery Insights',
                message:
                    'Recovery Companion could not load '
                    'your recovery information.',
                icon: Icons.cloud_off_outlined,
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
            ],
          );
        }

        final readResult = snapshot.data!;
        final response = readResult.data;

        final insights =
            _asMap(response['recovery_insights_data']);

        if (insights.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AppPageHeader(
                title: 'Recovery Insights',
                subtitle:
                    'A wider view of your recovery activity.',
                icon: Icons.insights_outlined,
              ),
              AppStatusMessage(
                title: 'Insights unavailable',
                message:
                    'No structured Recovery Insights '
                    'information was returned.',
                icon: Icons.info_outline,
                actionLabel: 'Refresh',
                onAction: _refresh,
              ),
            ],
          );
        }

        final sobrietyDays =
            insights['sobriety_days'];

        final sobrietyDate =
            (insights['sobriety_date'] ?? '').toString();

        final currentStep =
            insights['current_step'] ?? 1;

        final openAssignments =
            insights['open_step_assignments'] ?? 0;

        final activeGoals =
            insights['active_recovery_goals'] ?? 0;

        final checkinDays =
            insights['checkin_days_available'] ?? 0;

        final checkinWindow =
            insights['checkin_window_days'] ?? 7;

        final weekly =
            _asMap(insights['latest_weekly_snapshot']);

        final monthly =
            _asMap(insights['latest_monthly_snapshot']);

        return RefreshIndicator(
          onRefresh: _refreshAsync,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              32,
            ),
            children: [
              const AppPageHeader(
                title: 'Recovery Insights',
                subtitle:
                    'Notice patterns without turning '
                    'recovery into a score.',
                icon: Icons.insights_outlined,
              ),

              if (readResult.isCached) ...[
                OfflineCopyNotice(
                  cachedAt: readResult.cachedAt,
                  onRetry: _refresh,
                  detail:
                      'AI reflection still requires '
                      'a connection.',
                ),
                const SizedBox(height: 20),
              ],

              Column(
                key: const ValueKey(
                  'recovery-insights-summary',
                ),
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _InsightMetric(
                          icon:
                              Icons.wb_sunny_outlined,
                          label: 'Sobriety',
                          value: sobrietyDays == null
                              ? 'Not set'
                              : '$sobrietyDays days',
                          detail:
                              sobrietyDate.isEmpty
                              ? 'Sobriety date'
                              : 'Since $sobrietyDate',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InsightMetric(
                          icon: Icons
                              .format_list_numbered,
                          label: 'Step Work',
                          value:
                              'Step $currentStep',
                          detail:
                              '$openAssignments '
                              'open assignments',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _InsightMetric(
                          icon: Icons
                              .check_circle_outline,
                          label: 'Check-Ins',
                          value:
                              '$checkinDays of '
                              '$checkinWindow',
                          detail:
                              'recent days available',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InsightMetric(
                          icon: Icons.flag_outlined,
                          label: 'Goals',
                          value:
                              '$activeGoals active',
                          detail:
                              'recovery goals',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              const AppSectionTitle(
                title: 'Weekly View',
                subtitle:
                    'Your most recent saved '
                    'weekly review.',
              ),

              if (weekly.isEmpty)
                const AppStatusMessage(
                  title:
                      'No weekly review saved yet',
                  message:
                      'A saved weekly review will '
                      'appear here when available.',
                  icon: Icons
                      .calendar_view_week_outlined,
                )
              else
                _ReviewSnapshotCard(
                  icon: Icons
                      .calendar_view_week_outlined,
                  title:
                      'Latest Weekly Review',
                  period:
                      _weeklyPeriod(weekly),
                  metrics: [
                    '${weekly['checkin_days'] ?? 0} '
                        'check-in days',
                    '${weekly['journal_entries'] ?? 0} '
                        'journal entries',
                  ],
                ),

              const SizedBox(height: 28),

              const AppSectionTitle(
                title: 'Monthly View',
                subtitle:
                    'Your most recent rolling '
                    'recovery snapshot.',
              ),

              if (monthly.isEmpty)
                const AppStatusMessage(
                  title:
                      'No monthly review saved yet',
                  message:
                      'A saved monthly review will '
                      'appear here when available.',
                  icon: Icons
                      .calendar_month_outlined,
                )
              else
                _ReviewSnapshotCard(
                  icon: Icons
                      .calendar_month_outlined,
                  title:
                      'Latest Monthly Review',
                  period:
                      _monthlyPeriod(monthly),
                  metrics: [
                    '${monthly['weekly_reviews_included'] ?? 0} '
                        'of 4 weekly reviews',
                    '${monthly['checkin_days'] ?? 0} '
                        'check-in days',
                    '${monthly['journal_entries'] ?? 0} '
                        'journal entries',
                  ],
                ),

              const SizedBox(height: 28),

              const AppSectionTitle(
                title: 'AI Reflection',
                subtitle:
                    'Optional perspective, only when '
                    'you choose to send the summary.',
              ),

              AppSectionCard(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons
                              .privacy_tip_outlined,
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Only the locally built '
                            'Insights summary is sent '
                            'after you confirm. Raw '
                            'journal entries and check-in '
                            'notes are not included.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey(
                          'recovery-insights-ai',
                        ),
                        onPressed:
                            _analyzing ||
                                readResult.isCached
                            ? null
                            : _analyzeRecoveryInsights,
                        icon: _analyzing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .auto_awesome_outlined,
                              ),
                        label: Text(
                          _analyzing
                              ? 'Generating Reflection...'
                              : 'Reflect on Recovery Insights',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_aiError != null) ...[
                const SizedBox(height: 16),
                AppStatusMessage(
                  title:
                      'Reflection unavailable',
                  message: _aiError!,
                  icon: Icons.error_outline,
                ),
              ],

              if (_aiReflection != null) ...[
                const SizedBox(height: 16),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recovery Companion Reflection',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _aiReflection!,
                        key: const ValueKey(
                          'recovery-insights-ai-reflection',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _weeklyPeriod(
    Map<String, dynamic> snapshot,
  ) {
    final start =
        (snapshot['week_start'] ?? '').toString();

    final end =
        (snapshot['week_end'] ?? '').toString();

    if (start.isEmpty && end.isEmpty) {
      return 'Saved weekly snapshot';
    }

    return '$start ? $end';
  }

  static String _monthlyPeriod(
    Map<String, dynamic> snapshot,
  ) {
    final start =
        (snapshot['period_start'] ?? '').toString();

    final end =
        (snapshot['period_end'] ?? '').toString();

    if (start.isEmpty && end.isEmpty) {
      return (
        snapshot['snapshot_date'] ??
            'Saved monthly snapshot'
      ).toString();
    }

    return '$start ? $end';
  }
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ReviewSnapshotCard
    extends StatelessWidget {
  const _ReviewSnapshotCard({
    required this.icon,
    required this.title,
    required this.period,
    required this.metrics,
  });

  final IconData icon;
  final String title;
  final String period;
  final List<String> metrics;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer,
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context)
                      .colorScheme
                      .onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      period,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in metrics)
                Chip(
                  label: Text(metric),
                ),
            ],
          ),
        ],
      ),
    );
