import 'package:flutter/material.dart';

import 'api_client.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  late Future<Map<String, dynamic>> _routinesFuture;

  @override
  void initState() {
    super.initState();
    _routinesFuture = widget.apiClient.getRoutines();
  }

  void _refresh() {
    setState(() {
      _routinesFuture = widget.apiClient.getRoutines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _routinesFuture,
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
        final rawRoutines = data['routines'];

        final routines = rawRoutines is List
            ? rawRoutines
                .whereType<Map<String, dynamic>>()
                .toList()
            : <Map<String, dynamic>>[];

        if (routines.isEmpty) {
          return _EmptyRoutinesView(
            onRefresh: _refresh,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            final future = widget.apiClient.getRoutines();

            setState(() {
              _routinesFuture = future;
            });

            await future;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: routines.length,
            separatorBuilder: (_, _) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (context, index) {
              final routine = routines[index];

              final text = (
                routine['text'] ??
                routine['routine'] ??
                'Recovery routine'
              ).toString();

              final area = (
                routine['area'] ??
                'other'
              ).toString();

              final frequency = (
                routine['frequency'] ??
                ''
              ).toString();

              final dayOfWeek = (
                routine['day_of_week'] ??
                ''
              ).toString();

              final schedule = dayOfWeek.isNotEmpty
                  ? '$frequency - $dayOfWeek'
                  : frequency;

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
                      if (schedule.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Schedule: $schedule',
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

class _EmptyRoutinesView extends StatelessWidget {
  const _EmptyRoutinesView({
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
              Icons.repeat_outlined,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              'No active routines',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Active recovery routines will appear here.',
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
              'Unable to load routines',
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