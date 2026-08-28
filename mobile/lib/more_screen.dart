import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'chat_screen.dart';
import 'daily_checkin_screen.dart';
import 'fellowship_screen.dart';
import 'journal_screen.dart';
import 'local_data_ownership_repository.dart';
import 'local_daily_checkin_repository.dart';
import 'local_fellowship_repository.dart';
import 'local_journal_repository.dart';
import 'local_monthly_review_repository.dart';
import 'local_profile_repository.dart';
import 'local_step_work_repository.dart';
import 'local_weekly_review_repository.dart';
import 'monthly_review_screen.dart';
import 'offline_read_service.dart';
import 'profile_screen.dart';
import 'reminder_scheduler.dart';
import 'reminders_screen.dart';
import 'settings_privacy_screen.dart';
import 'step_work_screen.dart';
import 'weekly_review_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    required this.apiClient,
    this.offlineReadService,
    this.localDataOwnershipRepository,
    this.localDailyCheckInRepository,
    this.localFellowshipRepository,
    this.localJournalRepository,
    this.localMonthlyReviewRepository,
    this.localProfileRepository,
    this.localStepWorkRepository,
    this.localWeeklyReviewRepository,
    this.reminderScheduler,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineReadService? offlineReadService;
  final LocalDataOwnershipRepository? localDataOwnershipRepository;
  final LocalDailyCheckInRepository? localDailyCheckInRepository;
  final LocalFellowshipRepository? localFellowshipRepository;
  final LocalJournalRepository? localJournalRepository;
  final LocalMonthlyReviewRepository? localMonthlyReviewRepository;
  final LocalProfileRepository? localProfileRepository;
  final LocalStepWorkRepository? localStepWorkRepository;
  final LocalWeeklyReviewRepository? localWeeklyReviewRepository;
  final ReminderSchedulingService? reminderScheduler;

  void _open(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ToolScreen(title: title, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppPageHeader(
          title: 'More',
          subtitle: 'Recovery tools, connection, reviews, and your profile.',
          icon: Icons.apps_outlined,
        ),

        const AppSectionTitle(
          title: 'Today',
          subtitle: 'Tools for the next right thing.',
        ),

        _ToolGroup(
          children: [
            _ToolTile(
              icon: Icons.check_circle_outline,
              title: 'Daily Recovery',
              subtitle: 'Complete today\'s recovery check-in.',
              onTap: () {
                _open(
                  context,
                  title: 'Daily Recovery',
                  child: DailyCheckInScreen(
                    apiClient: apiClient,
                    offlineReadService: offlineReadService,
                    localRepository: localDailyCheckInRepository,
                  ),
                );
              },
            ),
            _ToolTile(
              icon: Icons.menu_book_outlined,
              title: 'Journal',
              subtitle: 'Write and review your recovery journal.',
              onTap: () {
                _open(
                  context,
                  title: 'Journal',
                  child: JournalScreen(
                    apiClient: apiClient,
                    offlineReadService: offlineReadService,
                    localRepository: localJournalRepository,
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Connection',
          subtitle: 'Stay connected with people and use AI as a support tool.',
        ),

        _ToolGroup(
          children: [
            _ToolTile(
              icon: Icons.groups_outlined,
              title: 'Fellowship',
              subtitle: 'Recovery contacts and connection recommendations.',
              onTap: () {
                _open(
                  context,
                  title: 'Fellowship',
                  child: FellowshipScreen(
                    apiClient: apiClient,
                    localRepository: localFellowshipRepository,
                  ),
                );
              },
            ),
            _ToolTile(
              icon: Icons.chat_bubble_outline,
              title: 'Recovery Companion',
              subtitle: 'Have a recovery-focused conversation with AI.',
              onTap: () {
                _open(
                  context,
                  title: 'Recovery Companion',
                  child: ChatScreen(apiClient: apiClient),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'Program',
          subtitle: 'Step work and periodic reflection.',
        ),

        _ToolGroup(
          children: [
            _ToolTile(
              icon: Icons.format_list_numbered,
              title: 'Step Work',
              subtitle: 'Review your current Step and assignments.',
              onTap: () {
                _open(
                  context,
                  title: 'Step Work',
                  child: StepWorkScreen(
                    apiClient: apiClient,
                    localRepository: localStepWorkRepository,
                  ),
                );
              },
            ),
            _ToolTile(
              icon: Icons.calendar_view_week_outlined,
              title: 'Weekly Review',
              subtitle: 'Review your recent recovery activity.',
              onTap: () {
                _open(
                  context,
                  title: 'Weekly Review',
                  child: WeeklyReviewScreen(
                    apiClient: apiClient,
                    localRepository: localWeeklyReviewRepository,
                  ),
                );
              },
            ),
            _ToolTile(
              icon: Icons.calendar_month_outlined,
              title: 'Monthly Review',
              subtitle: 'Review your rolling four-week recovery picture.',
              onTap: () {
                _open(
                  context,
                  title: 'Monthly Review',
                  child: MonthlyReviewScreen(
                    apiClient: apiClient,
                    localRepository: localMonthlyReviewRepository,
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 28),

        const AppSectionTitle(title: 'Account'),

        _ToolGroup(
          children: [
            _ToolTile(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'View and update your sobriety date.',
              onTap: () {
                _open(
                  context,
                  title: 'Profile',
                  child: ProfileScreen(
                    apiClient: apiClient,
                    offlineReadService: offlineReadService,
                    localRepository: localProfileRepository,
                  ),
                );
              },
            ),
            _ToolTile(
              icon: Icons.notifications_active_outlined,
              title: 'Reminders',
              subtitle: 'Choose private, device-based recovery reminders.',
              onTap: () {
                _open(
                  context,
                  title: 'Reminders',
                  child: RemindersScreen(scheduler: reminderScheduler),
                );
              },
            ),
            _ToolTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Settings & Privacy',
              subtitle: 'Export or permanently delete your recovery data.',
              onTap: () {
                _open(
                  context,
                  title: 'Settings & Privacy',
                  child: SettingsPrivacyScreen(
                    apiClient: apiClient,
                    offlineReadService: offlineReadService,
                    localRepository: localDataOwnershipRepository,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolGroup extends StatelessWidget {
  const _ToolGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, indent: 68),
          ],
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
