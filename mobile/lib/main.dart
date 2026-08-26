import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_theme.dart';
import 'daily_checkin_screen.dart';
import 'dashboard_screen.dart';
import 'goals_screen.dart';
import 'insights_screen.dart';
import 'mobile_config.dart';
import 'more_screen.dart';
import 'offline_read_service.dart';
import 'reminder_scheduler.dart';
import 'routines_screen.dart';
import 'secure_offline_cache_store.dart';
import 'weekly_review_screen.dart';

void main() {
  runApp(const RecoveryCompanionApp());
}

class RecoveryCompanionApp extends StatelessWidget {
  const RecoveryCompanionApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recovery Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  late final ApiClient _apiClient;
  late final OfflineReadService _offlineReadService;
  late final ReminderScheduler _reminderScheduler;

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
  void initState() {
    super.initState();

    _apiClient = ApiClient(
      baseUrl: MobileConfig.apiBaseUrl,
      apiToken: MobileConfig.apiToken,
    );

    _offlineReadService = OfflineReadService(
      cache: SecureOfflineCacheStore(
        storage: FlutterSecureKeyValueStore(),
      ),
    );

    _reminderScheduler = ReminderScheduler(
      onNotificationTap: _openReminderPayload,
    );

    _initializeReminderNavigation();
  }

  Future<void> _initializeReminderNavigation() async {
    await _reminderScheduler.initialize();

    if (!mounted) {
      return;
    }

    final payload =
        _reminderScheduler.takeLaunchPayload();

    if (payload == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _openReminderPayload(payload);
      }
    });
  }

  void _openReminderPayload(String payload) {
    if (!mounted) {
      return;
    }

    final kind = reminderKindFromPayload(payload);

    if (kind == null) {
      return;
    }

    late final String title;
    late final Widget screen;

    switch (kind) {
      case ReminderKind.dailyRecovery:
        title = 'Daily Recovery';
        screen = DailyCheckInScreen(
          apiClient: _apiClient,
          offlineReadService: _offlineReadService,
        );

      case ReminderKind.weeklyReview:
        title = 'Weekly Review';
        screen = WeeklyReviewScreen(
          apiClient: _apiClient,
        );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: screen,
        ),
      ),
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
        return DashboardScreen(
          apiClient: _apiClient,
          offlineReadService: _offlineReadService,
        );

      case 1:
        return InsightsScreen(
          apiClient: _apiClient,
        );

      case 2:
        return GoalsScreen(
          apiClient: _apiClient,
        );

      case 3:
        return RoutinesScreen(
          apiClient: _apiClient,
        );

      case 4:
        return MoreScreen(
          apiClient: _apiClient,
          offlineReadService: _offlineReadService,
          reminderScheduler: _reminderScheduler,
        );

      default:
        return DashboardScreen(
          apiClient: _apiClient,
          offlineReadService: _offlineReadService,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recovery Companion',
        ),
      ),
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
                icon: Icon(
                  destination.icon,
                ),
                label: destination.label,
              ),
            )
            .toList(),
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