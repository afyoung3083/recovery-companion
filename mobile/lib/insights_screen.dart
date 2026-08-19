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
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge,
              ),
            ],
          ),
        );
      },
    );
  }
}