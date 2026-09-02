import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_theme.dart';
import 'beta_support_action.dart';
import 'daily_checkin_screen.dart';
import 'dashboard_screen.dart';
import 'goals_screen.dart';
import 'insights_screen.dart';
import 'local_data_ownership_repository.dart';
import 'local_daily_checkin_repository.dart';
import 'local_dashboard_repository.dart';
import 'local_fellowship_repository.dart';
import 'local_goals_repository.dart';
import 'local_insights_repository.dart';
import 'local_journal_repository.dart';
import 'local_monthly_review_repository.dart';
import 'local_profile_repository.dart';
import 'local_routines_repository.dart';
import 'local_step_work_repository.dart';
import 'local_weekly_review_repository.dart';
import 'local_recovery_store.dart';
import 'mobile_config.dart';
import 'monthly_review_screen.dart';
import 'more_screen.dart';
import 'offline_read_service.dart';
import 'onboarding_gate.dart';
import 'onboarding_store.dart';
import 'profile_screen.dart';
import 'reminder_scheduler.dart';
import 'routines_screen.dart';
import 'secure_offline_cache_store.dart';
import 'step_work_screen.dart';
import 'weekly_review_screen.dart';

void main() {
  runApp(const RecoveryCompanionApp());
}

class RecoveryCompanionApp extends StatelessWidget {
  const RecoveryCompanionApp({this.onboardingStore, super.key});

  final OnboardingStore? onboardingStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recovery Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: OnboardingGate(store: onboardingStore, child: const HomeShell()),
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
  late final OfflineReadService _offlineReadService;
  late final ReminderScheduler _reminderScheduler;

  LocalDataOwnershipRepository? _localDataOwnershipRepository;
  LocalDailyCheckInRepository? _localDailyCheckInRepository;
  LocalDashboardRepository? _localDashboardRepository;
  LocalFellowshipRepository? _localFellowshipRepository;
  LocalGoalsRepository? _localGoalsRepository;
  LocalInsightsRepository? _localInsightsRepository;
  LocalJournalRepository? _localJournalRepository;
  LocalMonthlyReviewRepository? _localMonthlyReviewRepository;
  LocalProfileRepository? _localProfileRepository;
  LocalRoutinesRepository? _localRoutinesRepository;
  LocalStepWorkRepository? _localStepWorkRepository;
  LocalWeeklyReviewRepository? _localWeeklyReviewRepository;

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

    _offlineReadService = OfflineReadService(
      cache: SecureOfflineCacheStore(storage: FlutterSecureKeyValueStore()),
    );

    _reminderScheduler = ReminderScheduler(
      onNotificationTap: _openReminderPayload,
    );

    _initializeReminderNavigation();
    _initializeLocalRecovery();
  }

  Future<void> _initializeLocalRecovery() async {
    final store = await LocalRecoveryStore.openDefault();

    if (!mounted) {
      return;
    }

    setState(() {
      _localGoalsRepository = LocalGoalsRepository(store: store);
      _localInsightsRepository = LocalInsightsRepository(store: store);
      _localDailyCheckInRepository = LocalDailyCheckInRepository(store: store);
      _localDataOwnershipRepository = LocalDataOwnershipRepository(
        store: store,
      );
      _localDashboardRepository = LocalDashboardRepository(store: store);
      _localFellowshipRepository = LocalFellowshipRepository(store: store);

      _localJournalRepository = LocalJournalRepository(store: store);
      _localMonthlyReviewRepository = LocalMonthlyReviewRepository(
        store: store,
      );
      _localProfileRepository = LocalProfileRepository(store: store);
      _localRoutinesRepository = LocalRoutinesRepository(store: store);
      _localStepWorkRepository = LocalStepWorkRepository(store: store);
      _localWeeklyReviewRepository = LocalWeeklyReviewRepository(store: store);
    });
  }

  Future<void> _initializeReminderNavigation() async {
    await _reminderScheduler.initialize();

    if (!mounted) {
      return;
    }

    final payload = _reminderScheduler.takeLaunchPayload();

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
          localRepository: _localDailyCheckInRepository,
        );

      case ReminderKind.weeklyReview:
        title = 'Weekly Review';
        screen = WeeklyReviewScreen(
          apiClient: _apiClient,
          localRepository: _localWeeklyReviewRepository,
        );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: const [BetaSupportAction()],
          ),
          body: screen,
        ),
      ),
    );
  }

  Future<void> _openFeature({required String title, required Widget screen}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: const [BetaSupportAction()],
          ),
          body: screen,
        ),
      ),
    );
  }

  Future<void> _openInsightsDestination(InsightsDestination destination) {
    switch (destination) {
      case InsightsDestination.profile:
        return _openFeature(
          title: 'Profile',
          screen: ProfileScreen(
            apiClient: _apiClient,
            offlineReadService: _offlineReadService,
            localRepository: _localProfileRepository,
          ),
        );

      case InsightsDestination.stepWork:
        return _openFeature(
          title: 'Step Work',
          screen: StepWorkScreen(
            apiClient: _apiClient,
            localRepository: _localStepWorkRepository,
          ),
        );

      case InsightsDestination.dailyRecovery:
        return _openFeature(
          title: 'Daily Recovery',
          screen: DailyCheckInScreen(
            apiClient: _apiClient,
            offlineReadService: _offlineReadService,
            localRepository: _localDailyCheckInRepository,
          ),
        );

      case InsightsDestination.goals:
        return _openFeature(
          title: 'Goals',
          screen: GoalsScreen(
            apiClient: _apiClient,
            offlineReadService: _offlineReadService,
            localRepository: _localGoalsRepository,
          ),
        );

      case InsightsDestination.weeklyReview:
        return _openFeature(
          title: 'Weekly Review',
          screen: WeeklyReviewScreen(
            apiClient: _apiClient,
            localRepository: _localWeeklyReviewRepository,
          ),
        );

      case InsightsDestination.monthlyReview:
        return _openFeature(
          title: 'Monthly Review',
          screen: MonthlyReviewScreen(
            apiClient: _apiClient,
            localRepository: _localMonthlyReviewRepository,
          ),
        );
    }
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
          localRepository: _localDashboardRepository,
          localDailyCheckInRepository: _localDailyCheckInRepository,
          localFellowshipRepository: _localFellowshipRepository,
          localJournalRepository: _localJournalRepository,
          localProfileRepository: _localProfileRepository,
          localStepWorkRepository: _localStepWorkRepository,
        );

      case 1:
        return InsightsScreen(
          apiClient: _apiClient,
          offlineReadService: _offlineReadService,
          localRepository: _localInsightsRepository,
          onOpenDestination: _openInsightsDestination,
        );

      case 2:
        return GoalsScreen(
          apiClient: _apiClient,
          offlineReadService: _offlineReadService,
          localRepository: _localGoalsRepository,
        );

      case 3:
        return RoutinesScreen(
          apiClient: _apiClient,
          offlineReadService: _offlineReadService,
          localRepository: _localRoutinesRepository,
        );

      case 4:
        return MoreScreen(
          apiClient: _apiClient,
          offlineReadService: _offlineReadService,
          localDataOwnershipRepository: _localDataOwnershipRepository,
          localDailyCheckInRepository: _localDailyCheckInRepository,
          localFellowshipRepository: _localFellowshipRepository,
          localJournalRepository: _localJournalRepository,
          localMonthlyReviewRepository: _localMonthlyReviewRepository,
          localProfileRepository: _localProfileRepository,
          localStepWorkRepository: _localStepWorkRepository,
          localWeeklyReviewRepository: _localWeeklyReviewRepository,
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
        title: const Text('Recovery Companion'),
        actions: const [BetaSupportAction()],
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
                icon: Icon(destination.icon),
                label: destination.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Destination {
  const _Destination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
