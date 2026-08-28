import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'offline_copy_notice.dart';
import 'offline_read_service.dart';
import 'contact_profile_screen.dart';
import 'daily_checkin_screen.dart';
import 'journal_screen.dart';
import 'local_daily_checkin_repository.dart';
import 'local_dashboard_repository.dart';
import 'local_fellowship_repository.dart';
import 'local_journal_repository.dart';
import 'local_profile_repository.dart';
import 'local_step_work_repository.dart';
import 'profile_screen.dart';
import 'step_work_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.apiClient,
    this.offlineReadService,
    this.localRepository,
    this.localDailyCheckInRepository,
    this.localFellowshipRepository,
    this.localJournalRepository,
    this.localProfileRepository,
    this.localStepWorkRepository,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineReadService? offlineReadService;
  final LocalDashboardRepository? localRepository;
  final LocalDailyCheckInRepository? localDailyCheckInRepository;
  final LocalFellowshipRepository? localFellowshipRepository;
  final LocalJournalRepository? localJournalRepository;
  final LocalProfileRepository? localProfileRepository;
  final LocalStepWorkRepository? localStepWorkRepository;

  @override
  State<DashboardScreen> createState() {
    return _DashboardScreenState();
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<OfflineReadResult> _dashboardFuture;

  Future<OfflineReadResult> _loadDashboard() async {
    final localRepository = widget.localRepository;

    if (localRepository != null) {
      final data = await localRepository.getDashboard();

      return OfflineReadResult(data: data, source: OfflineReadSource.network);
    }

    final service = widget.offlineReadService;

    if (service == null) {
      final data = await widget.apiClient.getDashboard();

      return OfflineReadResult(data: data, source: OfflineReadSource.network);
    }

    return service.read(
      cacheKey: OfflineCacheKeys.dashboard,
      networkRead: widget.apiClient.getDashboard,
    );
  }

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  void _refresh() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  Future<void> _refreshAsync() async {
    final future = _loadDashboard();

    setState(() {
      _dashboardFuture = future;
    });

    await future;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value.whereType<Map<String, dynamic>>().toList();
  }

  String _contactType(String value) {
    if (value.isEmpty) {
      return 'Recovery contact';
    }

    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                    '${word.substring(1)}',
        )
        .join(' ');
  }

  Future<void> _openContact(Map<String, dynamic> contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactProfileScreen(
          apiClient: widget.apiClient,
          contact: contact,
          localRepository: widget.localFellowshipRepository,
        ),
      ),
    );

    if (mounted) {
      _refresh();
    }
  }

  Future<void> _openScreen({
    required String title,
    required Widget screen,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: screen,
        ),
      ),
    );

    if (mounted) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OfflineReadResult>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AppPageHeader(
                title: 'Dashboard',
                subtitle: 'A clear view of your recovery today.',
                icon: Icons.favorite_outline,
              ),
              AppStatusMessage(
                title: 'Unable to load Dashboard',
                message:
                    'Recovery Companion could not load '
                    'your current recovery information.',
                icon: Icons.cloud_off_outlined,
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
            ],
          );
        }

        final readResult = snapshot.data!;
        final response = readResult.data;
        final dashboard = _asMap(response['dashboard_data']);

        if (dashboard.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AppPageHeader(
                title: 'Dashboard',
                subtitle: 'A clear view of your recovery today.',
                icon: Icons.favorite_outline,
              ),
              AppStatusMessage(
                title: 'Dashboard unavailable',
                message:
                    'No structured Dashboard information '
                    'was returned.',
                icon: Icons.info_outline,
                actionLabel: 'Refresh',
                onAction: _refresh,
              ),
            ],
          );
        }

        final sobrietyDays = dashboard['sobriety_days'];

        final sobrietyDate = (dashboard['sobriety_date'] ?? '').toString();

        final checkin = _asMap(dashboard['today_checkin']);

        final checkinSaved = checkin['saved'] == true;

        final completedCount = checkin['completed_count'] ?? 0;

        final checkinTotal = checkin['total'] ?? 0;

        final checkinNote = (checkin['note'] ?? '').toString().trim();

        final currentStep = dashboard['current_step'] ?? 1;

        final assignments = _asMapList(dashboard['open_assignments']);

        final latestJournalRaw = dashboard['latest_journal_entry'];

        final latestJournal = latestJournalRaw == null
            ? null
            : _asMap(latestJournalRaw);

        final contacts = _asMapList(dashboard['recommended_contacts']);

        return RefreshIndicator(
          onRefresh: _refreshAsync,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const AppPageHeader(
                title: 'Dashboard',
                subtitle: 'A clear view of your recovery today.',
                icon: Icons.favorite_outline,
              ),

              if (readResult.isCached) ...[
                OfflineCopyNotice(
                  cachedAt: readResult.cachedAt,
                  onRetry: _refresh,
                ),
                const SizedBox(height: 16),
              ],

              _SobrietyCard(
                sobrietyDays: sobrietyDays,
                sobrietyDate: sobrietyDate,
                onTap: () {
                  _openScreen(
                    title: 'Profile',
                    screen: ProfileScreen(
                      apiClient: widget.apiClient,
                      offlineReadService: widget.offlineReadService,
                      localRepository: widget.localProfileRepository,
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SummaryCard(
                      key: const ValueKey('dashboard-checkin'),
                      icon: Icons.check_circle_outline,
                      label: 'Today',
                      value: checkinSaved
                          ? '$completedCount of '
                                '$checkinTotal'
                          : 'Not checked in',
                      detail: checkinSaved
                          ? 'recovery actions'
                          : 'Daily Recovery',
                      onTap: () {
                        _openScreen(
                          title: 'Daily Recovery',
                          screen: DailyCheckInScreen(
                            apiClient: widget.apiClient,
                            offlineReadService: widget.offlineReadService,
                            localRepository: widget.localDailyCheckInRepository,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      key: const ValueKey('dashboard-current-step'),
                      icon: Icons.format_list_numbered,
                      label: 'Step Work',
                      value: 'Step $currentStep',
                      detail: assignments.isEmpty
                          ? 'No open assignments'
                          : '${assignments.length} open '
                                '${assignments.length == 1 ? 'assignment' : 'assignments'}',
                      onTap: () {
                        _openScreen(
                          title: 'Step Work',
                          screen: StepWorkScreen(
                            apiClient: widget.apiClient,
                            localRepository: widget.localStepWorkRepository,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              if (checkinNote.isNotEmpty) ...[
                const SizedBox(height: 16),
                AppSectionCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s note',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              checkinNote,
                              key: const ValueKey('dashboard-daily-note'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              const AppSectionTitle(
                title: 'Step Work',
                subtitle: 'What is currently in front of you.',
              ),

              if (assignments.isEmpty)
                const AppStatusMessage(
                  title: 'No open assignments',
                  message:
                      'Your current Step has no '
                      'unfinished assignments.',
                  icon: Icons.task_alt,
                )
              else
                ...assignments.map((assignment) {
                  final id = assignment['id'];

                  final text = (assignment['text'] ?? 'Step assignment')
                      .toString();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppSectionCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              id?.toString() ?? '?',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              text,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 18),

              const AppSectionTitle(
                title: 'Latest Journal',
                subtitle: 'A recent reflection from your journal.',
              ),

              if (latestJournal == null || latestJournal.isEmpty)
                const AppStatusMessage(
                  title: 'No journal entries yet',
                  message:
                      'Your latest journal entry will '
                      'appear here.',
                  icon: Icons.menu_book_outlined,
                )
              else
                InkWell(
                  key: const ValueKey('dashboard-journal-card'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _openScreen(
                      title: 'Journal',
                      screen: JournalScreen(
                        apiClient: widget.apiClient,
                        offlineReadService: widget.offlineReadService,
                        localRepository: widget.localJournalRepository,
                      ),
                    );
                  },
                  child: AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                (latestJournal['created_at'] ?? '')
                                    .toString()
                                    .split('T')
                                    .first,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (latestJournal['text'] ?? '').toString(),
                          key: const ValueKey('dashboard-latest-journal'),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 28),

              const AppSectionTitle(
                title: 'Fellowship',
                subtitle: 'People you may want to stay connected with.',
              ),

              if (contacts.isEmpty)
                const AppStatusMessage(
                  title: 'No contacts available',
                  message:
                      'Add fellowship contacts to see '
                      'recommendations here.',
                  icon: Icons.groups_outlined,
                )
              else
                AppSectionCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (var index = 0; index < contacts.length; index++) ...[
                        ListTile(
                          key: ValueKey(
                            'dashboard-contact-${contacts[index]['id']}',
                          ),
                          leading: CircleAvatar(
                            child: Icon(
                              index == 0
                                  ? Icons.star_outline
                                  : Icons.person_outline,
                            ),
                          ),
                          title: Text(
                            (contacts[index]['handle'] ?? 'Recovery contact')
                                .toString(),
                          ),
                          subtitle: Text(
                            _contactType(
                              (contacts[index]['contact_type'] ?? '')
                                  .toString(),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _openContact(contacts[index]);
                          },
                        ),
                        if (index < contacts.length - 1)
                          const Divider(height: 1, indent: 72),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SobrietyCard extends StatelessWidget {
  const _SobrietyCard({
    required this.sobrietyDays,
    required this.sobrietyDate,
    required this.onTap,
  });

  final dynamic sobrietyDays;
  final String sobrietyDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final hasDate = sobrietyDays != null;

    return InkWell(
      key: const ValueKey('dashboard-sobriety-card'),
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.wb_sunny_outlined,
                color: scheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sobriety',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasDate ? '$sobrietyDays days' : 'Date not set',
                    key: const ValueKey('dashboard-sobriety-days'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sobrietyDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Since $sobrietyDate',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AppSectionCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
