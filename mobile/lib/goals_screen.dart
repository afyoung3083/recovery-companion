import 'package:flutter/material.dart';

import 'api_client.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late Future<Map<String, dynamic>> _goalsFuture;

  @override
  void initState() {
    super.initState();
    _goalsFuture = widget.apiClient.getGoals();
  }

  void _refresh() {
    setState(() {
      _goalsFuture = widget.apiClient.getGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _goalsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _ErrorView(
            message: snapshot.error.toString(),
            onRetry: _refresh,
          );
        }

        final data = snapshot.data ?? const {};
        final rawGoals = data['goals'];

        final goals = rawGoals is List
            ? rawGoals
                .whereType<Map<String, dynamic>>()
                .toList()
            : <Map<String, dynamic>>[];

        if (goals.isEmpty) {
          return _EmptyGoalsView(
            onRefresh: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            final future = widget.apiClient.getGoals();

            setState(() {
              _goalsFuture = future;
            });

            await future;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            separatorBuilder: (_, _) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (context, index) {
              final goal = goals[index];

              final text = (
                goal['text'] ??
                goal['goal'] ??
                'Recovery goal'
              ).toString();

              final area = (
                goal['area'] ??
                'other'
              ).toString();

              final targetDate = (
                goal['target_date'] ??
                ''
              ).toString();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Area: $area',
                      ),
                      if (targetDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Target: $targetDate',
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyGoalsView extends StatelessWidget {
  const _EmptyGoalsView({
    required this.onRefresh,
  });

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              'No active goals',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Active recovery goals will appear here.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRefresh,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
              'Unable to load goals',
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}