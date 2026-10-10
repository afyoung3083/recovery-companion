import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
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
  const HomeShell({
    this.localStoreLoader,
    this.reminderFactory,
    this.apiClient,
    super.key,
  });

  final Future<LocalRecoveryStore> Function()? localStoreLoader;
  final ReminderScheduler Function(ValueChanged<String>)? reminderFactory;
  final ApiClient? apiClient;

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

  bool _localInitializationPending = true;
  bool _localInitializationFailed = false;
  ReminderKind? _pendingReminder;
  bool _reminderRouteOpen = false;
  int _dashboardRefreshVersion = 0;

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

    _apiClient = widget.apiClient ?? ApiClient(
      baseUrl: MobileConfig.apiBaseUrl,
      apiToken: MobileConfig.apiToken,
    );

    _offlineReadService = OfflineReadService(
      cache: SecureOfflineCacheStore(storage: FlutterSecureKeyValueStore()),
    );

    _reminderScheduler =
        widget.reminderFactory?.call(_openReminderPayload) ??
        ReminderScheduler(onNotificationTap: _openReminderPayload);

    unawaited(_initializeLocalRecovery());
    unawaited(_initializeReminderNavigation());
  }

  Future<void> _initializeLocalRecovery() async {
    setState(() {
      _localInitializationPending = true;
      _localInitializationFailed = false;
    });

    try {
      final loader = widget.localStoreLoader ?? LocalRecoveryStore.openDefault;
      final store = await loader();

      if (!mounted) {
        return;
      }

      // Verify readability before exposing forms. Never clear or replace
      // unreadable recovery records or silently use the legacy API instead.
      await store.read();

      if (!mounted) {
        return;
      }

      setState(() {
        _localGoalsRepository = LocalGoalsRepository(store: store);
        _localInsightsRepository = LocalInsightsRepository(store: store);
        _localDailyCheckInRepository = LocalDailyCheckInRepository(
          store: store,
        );
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
        _localWeeklyReviewRepository = LocalWeeklyReviewRepository(
          store: store,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _localInitializationFailed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _localInitializationPending = false;
        });
      }
    }

    _dispatchPendingReminder();
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
    final kind = reminderKindFromPayload(payload);

    if (!mounted || kind == null || _reminderRouteOpen) {
      return;
    }

    // Retain the request during startup, including a failed startup that
    // the user subsequently retries. Never construct a server-first form.
    _pendingReminder = kind;
    _dispatchPendingReminder();
  }

  void _dispatchPendingReminder() {
    final kind = _pendingReminder;

    if (!mounted ||
        kind == null ||
        _localInitializationPending ||
        _localInitializationFailed ||
        _reminderRouteOpen ||
        _localDailyCheckInRepository == null ||
        _localWeeklyReviewRepository == null) {
      return;
    }

    _pendingReminder = null;
    _reminderRouteOpen = true;

    // Navigation runs after the current frame, not during widget building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_showReadyReminder(kind));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _showReadyReminder(ReminderKind kind) async {
    try {
      late final String title;
      late final Widget screen;

      switch (kind) {
        case ReminderKind.dailyRecovery:
          title = 'Daily Recovery';
          screen = DailyCheckInScreen(
            apiClient: _apiClient,
            offlineReadService: _offlineReadService,
            localRepository: _localDailyCheckInRepository!,
          );

        case ReminderKind.weeklyReview:
          title = 'Weekly Review';
          screen = WeeklyReviewScreen(
            apiClient: _apiClient,
            localRepository: _localWeeklyReviewRepository!,
          );
      }

      await _openFeature(title: title, screen: screen);
    } finally {
      _reminderRouteOpen = false;

      if (mounted) {
        // Refresh the existing Dashboard state, not its route or app state.
        setState(() {
          _dashboardRefreshVersion++;
        });
      }
    }
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
    if (widget.apiClient == null) {
      _apiClient.close();
    }
    super.dispose();
  }

  Widget _buildSelectedScreen() {
    if (_localInitializationPending) {
      return const Center(
        key: ValueKey('local-recovery-startup-loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_localInitializationFailed) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppStatusMessage(
            key: const ValueKey('local-recovery-startup-error'),
            title: 'Recovery data could not be opened',
            message:
                'Your records were not deleted. Retry before opening '
                'or saving a check-in.',
            icon: Icons.lock_outline,
            actionLabel: 'Retry',
            onAction: () => unawaited(_initializeLocalRecovery()),
          ),
        ],
      );
    }

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
          localInitializationPending: _localInitializationPending,
          refreshVersion: _dashboardRefreshVersion,
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
