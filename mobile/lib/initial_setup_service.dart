import 'local_goals_repository.dart';
import 'local_profile_repository.dart';
import 'local_recovery_store.dart';
import 'local_routines_repository.dart';
import 'reminder_preferences.dart';
import 'reminder_scheduler.dart';

class InitialSetupDraft {
  const InitialSetupDraft({
    this.sobrietyDate = '',
    this.goalText = '',
    this.routineText = '',
    this.dailyReminderEnabled = false,
    this.weeklyReminderEnabled = false,
    this.descriptiveNotifications = false,
  });

  final String sobrietyDate;
  final String goalText;
  final String routineText;
  final bool dailyReminderEnabled;
  final bool weeklyReminderEnabled;
  final bool descriptiveNotifications;

  bool get hasAnySelection {
    return sobrietyDate.trim().isNotEmpty ||
        goalText.trim().isNotEmpty ||
        routineText.trim().isNotEmpty ||
        dailyReminderEnabled ||
        weeklyReminderEnabled;
  }
}

class InitialSetupService {
  InitialSetupService({
    required this.profileRepository,
    required this.goalsRepository,
    required this.routinesRepository,
    required this.reminderPreferencesRepository,
    required this.reminderScheduler,
  });

  final LocalProfileRepository profileRepository;
  final LocalGoalsRepository goalsRepository;
  final LocalRoutinesRepository routinesRepository;
  final ReminderPreferencesRepository reminderPreferencesRepository;
  final ReminderSchedulingService reminderScheduler;

  static Future<InitialSetupService> openDefault() async {
    final store = await LocalRecoveryStore.openDefault();

    return InitialSetupService(
      profileRepository: LocalProfileRepository(store: store),
      goalsRepository: LocalGoalsRepository(store: store),
      routinesRepository: LocalRoutinesRepository(store: store),
      reminderPreferencesRepository: ReminderPreferencesRepository(
        storage: SharedPreferencesReminderStorage(),
      ),
      reminderScheduler: ReminderScheduler(),
    );
  }

  Future<void> apply(InitialSetupDraft draft) async {
    final sobrietyDate = draft.sobrietyDate.trim();
    final goalText = draft.goalText.trim();
    final routineText = draft.routineText.trim();

    if (sobrietyDate.isNotEmpty) {
      await profileRepository.updateSobrietyDate(sobrietyDate);
    }

    if (goalText.isNotEmpty) {
      await goalsRepository.createGoal(text: goalText, area: 'recovery');
    }

    if (routineText.isNotEmpty) {
      await routinesRepository.createRoutine(
        text: routineText,
        area: 'recovery',
        frequency: 'daily',
      );
    }

    final preferences = ReminderPreferences.defaults().copyWith(
      dailyRecoveryEnabled: draft.dailyReminderEnabled,
      weeklyReviewEnabled: draft.weeklyReminderEnabled,
      privacyMode: draft.descriptiveNotifications
          ? NotificationPrivacyMode.descriptive
          : NotificationPrivacyMode.private,
    );

    await reminderPreferencesRepository.save(preferences);

    if (draft.dailyReminderEnabled || draft.weeklyReminderEnabled) {
      final granted = await reminderScheduler.requestPermission();

      if (granted) {
        await reminderScheduler.apply(preferences);
      }
    }
  }
}
