import 'package:flutter/material.dart';

import 'api_client.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<DashboardScreen> createState() {
    return _DashboardScreenState();
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = widget.apiClient.getDashboard();
  }

  void _refresh() {
    setState(() {
      _dashboardFuture = widget.apiClient.getDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
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
                    'Unable to load Dashboard',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey(
                      'dashboard-retry',
                    ),
                    onPressed: _refresh,
                    child: const Text(
                      'Retry',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? const {};
        final dashboard = (
          data['dashboard'] ??
          'No Dashboard information available.'
        ).toString();

        return RefreshIndicator(
          onRefresh: () async {
            final future =
                widget.apiClient.getDashboard();

            setState(() {
              _dashboardFuture = future;
            });

            await future;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Dashboard',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium,
              ),
              const SizedBox(height: 20),
              SelectableText(
                dashboard,
                key: const ValueKey(
                  'dashboard-summary',
                ),
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
