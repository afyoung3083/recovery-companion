import 'package:flutter/material.dart';

import 'api_client.dart';
import 'chat_screen.dart';
import 'daily_checkin_screen.dart';
import 'fellowship_screen.dart';
import 'goals_screen.dart';
import 'insights_screen.dart';
import 'journal_screen.dart';
import 'mobile_config.dart';
import 'monthly_review_screen.dart';
import 'routines_screen.dart';
import 'step_work_screen.dart';
import 'weekly_review_screen.dart';

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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
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

  late final ApiClient _apiClient;

  static const List<_Destination> _destinations = [
    _Destination(label: 'Dashboard', icon: Icons.dashboard_outlined),
    _Destination(label: 'Insights', icon: Icons.insights_outlined),
    _Destination(label: 'Goals', icon: Icons.flag_outlined),
    _Destination(label: 'Routines', icon: Icons.repeat_outlined),
    _Destination(label: 'More', icon: Icons.menu),
  ];

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient(
      baseUrl: MobileConfig.apiBaseUrl,
      apiToken: MobileConfig.apiToken,
    );
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Widget _buildSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return DashboardScreen(apiClient: _apiClient);

      case 1:
        return InsightsScreen(apiClient: _apiClient);

      case 2:
        return GoalsScreen(apiClient: _apiClient);

      case 3:
        return RoutinesScreen(apiClient: _apiClient);

      case 4:
        return MoreScreen(apiClient: _apiClient);

      default:
        return DashboardScreen(apiClient: _apiClient);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Companion')),
      body: _buildSelectedScreen(),
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
  const DashboardScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<DashboardScreen> createState() {
    return _DashboardScreenState();
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _healthFuture;

  @override
  void initState() {
    super.initState();

    _healthFuture = widget.apiClient.getHealth();
  }

  void _refreshHealth() {
    setState(() {
      _healthFuture = widget.apiClient.getHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _healthFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text('Backend unavailable'),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
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

        final health = (snapshot.data ?? const <String, dynamic>{});

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  'Backend status: '
                  '${health['status'] ?? 'unknown'}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Backend version: '
                  '${health['version'] ?? 'unknown'}',
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

class MoreScreen extends StatelessWidget {
  const MoreScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('More', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Additional recovery tools'),
        const SizedBox(height: 20),

        _MoreMenuTile(
          icon: Icons.chat_bubble_outline,
          title: 'Chat',
          subtitle: 'Talk with your Recovery Companion.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ToolScreen(
                  title: 'Chat',
                  child: ChatScreen(apiClient: apiClient),
                ),
              ),
            );
          },
        ),

        _MoreMenuTile(
          icon: Icons.check_circle_outline,
          title: 'Daily Recovery',
          subtitle: 'Complete today\'s recovery check-in.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ToolScreen(
                  title: 'Daily Recovery',
                  child: DailyCheckInScreen(apiClient: apiClient),
                ),
              ),
            );
          },
        ),

        _MoreMenuTile(
          icon: Icons.menu_book_outlined,
          title: 'Journal',
          subtitle: 'Write, review, and search journal entries.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ToolScreen(
                  title: 'Journal',
                  child: JournalScreen(apiClient: apiClient),
                ),
              ),
            );
          },
        ),

        _MoreMenuTile(
          icon: Icons.groups_outlined,
          title: 'Fellowship',
          subtitle: 'Manage recovery contacts and recommendations.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ToolScreen(
                  title: 'Fellowship',
                  child: FellowshipScreen(apiClient: apiClient),
                ),
              ),
            );
          },
        ),

        _MoreMenuTile(
          icon: Icons.format_list_numbered,
          title: 'Step Work',
          subtitle: 'Review your current Step and assignments.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ToolScreen(
                  title: 'Step Work',
                  child: StepWorkScreen(apiClient: apiClient),
                ),
              ),
            );
          },
        ),

        _MoreMenuTile(
          icon: Icons.calendar_view_week_outlined,
          title: 'Weekly Review',
          subtitle: 'Review and save your weekly recovery activity.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ToolScreen(
                  title: 'Weekly Review',
                  child: WeeklyReviewScreen(apiClient: apiClient),
                ),
              ),
            );
          },
        ),

        _MoreMenuTile(
          icon: Icons.calendar_month_outlined,
          title: 'Monthly Review',
          subtitle: 'Review and save your rolling four-week recovery summary.',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ToolScreen(
                  title: 'Monthly Review',
                  child: MonthlyReviewScreen(apiClient: apiClient),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MoreMenuTile extends StatelessWidget {
  const _MoreMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ToolScreen extends StatelessWidget {
  const _ToolScreen({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _Destination {
  const _Destination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
