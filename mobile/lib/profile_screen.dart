import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<ProfileScreen> createState() {
    return _ProfileScreenState();
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.apiClient.getProfile();
  }

  void _refresh() {
    setState(() {
      _saveError = null;
      _profileFuture = widget.apiClient.getProfile();
    });
  }

  DateTime _initialDate(String? sobrietyDate) {
    final today = DateTime.now();

    final parsed = sobrietyDate == null
        ? null
        : DateTime.tryParse(sobrietyDate);

    if (parsed == null || parsed.isAfter(today)) {
      return today;
    }

    return parsed;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Future<void> _chooseSobrietyDate(String? currentDate) async {
    final today = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _initialDate(currentDate),
      firstDate: DateTime(1900, 1, 1),
      lastDate: today,
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final result = await widget.apiClient.updateSobrietyDate(
        _formatDate(selectedDate),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profileFuture = Future.value(result);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saveError = 'Unable to save your sobriety date. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const AppPageHeader(
                title: 'Your Profile',
                subtitle: 'Recovery information that helps personalize your experience.',
                icon: Icons.person_outline,
              ),
              AppStatusMessage(
                title: 'Unable to load profile',
                message: 'Recovery Companion could not load your profile information.',
                icon: Icons.cloud_off_outlined,
                actionLabel: 'Retry',
                onAction: _refresh,
              ),
            ],
          );
        }

        final data = snapshot.data ?? const {};
        final rawProfile = data['profile'];

        final profile = rawProfile is Map<String, dynamic>
            ? rawProfile
            : const <String, dynamic>{};

        final rawSobrietyDate = profile['sobriety_date'];

        final sobrietyDate = rawSobrietyDate?.toString();

        final hasSobrietyDate = sobrietyDate != null && sobrietyDate.isNotEmpty;

        final displayDate = hasSobrietyDate ? sobrietyDate : 'Not set';

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const AppPageHeader(
              title: 'Your Profile',
              subtitle: 'Recovery information that helps personalize your experience.',
              icon: Icons.person_outline,
            ),

            const AppSectionTitle(
              title: 'Recovery',
              subtitle:
                  'Your sobriety date is used throughout Recovery Companion.',
            ),

            Container(
              key: const ValueKey('profile-sobriety-card'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.wb_sunny_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sobriety Date',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayDate,
                              key: const ValueKey('profile-sobriety-date'),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    hasSobrietyDate
                        ? 'Recovery Companion uses this date to calculate sobriety time across your dashboard and recovery views.'
                        : 'Set your sobriety date when you are ready. You can change it later.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('profile-change-sobriety-date'),
                      onPressed: _saving
                          ? null
                          : () {
                              _chooseSobrietyDate(sobrietyDate);
                            },
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : hasSobrietyDate
                            ? 'Change Sobriety Date'
                            : 'Set Sobriety Date',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_saveError != null) ...[
              const SizedBox(height: 16),
              AppStatusMessage(
                title: 'Unable to save',
                message: _saveError!,
                icon: Icons.error_outline,
              ),
            ],

            const SizedBox(height: 28),

            const AppSectionTitle(title: 'About your profile'),

            const AppSectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Additional profile preferences will appear here as Recovery Companion adds personalization, privacy, appearance, and companion options.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
