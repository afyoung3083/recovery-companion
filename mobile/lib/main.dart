import 'package:flutter/material.dart';

import 'api_client.dart';

void main() {
  runApp(const RecoveryCompanionApp());
}

class RecoveryCompanionApp extends StatelessWidget {
  const RecoveryCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recovery Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<_Destination> _destinations = [
    _Destination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
    ),
    _Destination(
      label: 'Insights',
      icon: Icons.insights_outlined,
    ),
    _Destination(
      label: 'Goals',
      icon: Icons.flag_outlined,
    ),
    _Destination(
      label: 'Routines',
      icon: Icons.repeat_outlined,
    ),
    _Destination(
      label: 'More',
      icon: Icons.menu,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Companion'),
      ),
      body: _selectedIndex == 0
          ? const DashboardScreen()
          : _ScreenPlaceholder(
              title: destination.label,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                label: destination.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ApiClient _apiClient;
  late Future<Map<String, dynamic>> _healthFuture;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient(
      baseUrl: 'http://10.0.2.2:8000',
    );

    _healthFuture = _apiClient.getHealth();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  void _refreshHealth() {
    setState(() {
      _healthFuture = _apiClient.getHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _healthFuture,
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
                    'Backend unavailable',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refreshHealth,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final health = snapshot.data ?? const {};

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_outline,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  'Backend status: ${health['status'] ?? 'unknown'}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Backend version: ${health['version'] ?? 'unknown'}',
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _refreshHealth,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScreenPlaceholder extends StatelessWidget {
  const _ScreenPlaceholder({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Sprint 32 mobile foundation',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}