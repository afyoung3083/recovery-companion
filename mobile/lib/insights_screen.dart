import 'package:flutter/material.dart';

import 'api_client.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Future<Map<String, dynamic>> _insightsFuture;

  bool _analyzing = false;
  String? _aiError;
  String? _aiReflection;

  @override
  void initState() {
    super.initState();
    _insightsFuture = widget.apiClient.getRecoveryInsights();
  }

  void _refresh() {
    setState(() {
      _insightsFuture = widget.apiClient.getRecoveryInsights();
    });
  }

  Future<void> _analyzeRecoveryInsights() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Analyze Recovery Insights?',
          ),
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
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Analyze Insights',
              ),
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

      final reflection = (
        result['reflection'] ??
        ''
      ).toString().trim();

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
            'Unable to generate Recovery Insights reflection. '
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _insightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load Recovery Insights',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? const {};
        final insights = (
          data['recovery_insights'] ??
          'No Recovery Insights available.'
        ).toString();

        return RefreshIndicator(
          onRefresh: () async {
            final future = widget.apiClient.getRecoveryInsights();

            setState(() {
              _insightsFuture = future;
            });

            await future;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Recovery Insights',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium,
              ),
              const SizedBox(height: 20),
              SelectableText(
                insights,
                key: const ValueKey(
                  'recovery-insights-summary',
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge,
              ),

              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 20),

              Text(
                'AI Reflection',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),

              const SizedBox(height: 8),

              const Text(
                'AI reflection is optional. Recovery Companion sends '
                'only the locally built Recovery Insights summary '
                'when you explicitly confirm.',
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                key: const ValueKey(
                  'recovery-insights-ai',
                ),
                onPressed: _analyzing
                    ? null
                    : _analyzeRecoveryInsights,
                icon: _analyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome_outlined,
                      ),
                label: Text(
                  _analyzing
                      ? 'Generating Reflection...'
                      : 'Reflect on Recovery Insights',
                ),
              ),

              if (_aiError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _aiError!,
                  key: const ValueKey(
                    'recovery-insights-ai-error',
                  ),
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error,
                  ),
                ),
              ],

              if (_aiReflection != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recovery Companion Reflection',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          _aiReflection!,
                          key: const ValueKey(
                            'recovery-insights-ai-reflection',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
