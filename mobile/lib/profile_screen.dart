import 'package:flutter/material.dart';

import 'api_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.apiClient,
    super.key,
  });

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

  DateTime _initialDate(
    String? sobrietyDate,
  ) {
    final today = DateTime.now();
    final parsed = sobrietyDate == null
        ? null
        : DateTime.tryParse(
            sobrietyDate,
          );

    if (parsed == null || parsed.isAfter(today)) {
      return today;
    }

    return parsed;
  }

  String _formatDate(
    DateTime date,
  ) {
    final year = date.year.toString().padLeft(
      4,
      '0',
    );
    final month = date.month.toString().padLeft(
      2,
      '0',
    );
    final day = date.day.toString().padLeft(
      2,
      '0',
    );

    return '$year-$month-$day';
  }

  Future<void> _chooseSobrietyDate(
    String? currentDate,
  ) async {
    final today = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _initialDate(
        currentDate,
      ),
      firstDate: DateTime(
        1900,
        1,
        1,
      ),
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
      final result =
          await widget.apiClient.updateSobrietyDate(
        _formatDate(
          selectedDate,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profileFuture = Future.value(
          result,
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saveError =
            'Unable to save sobriety date. Please try again.';
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
                    'Unable to load Profile',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey(
                      'profile-retry',
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
        final rawProfile = data['profile'];

        final profile = rawProfile
                is Map<String, dynamic>
            ? rawProfile
            : const <String, dynamic>{};

        final rawSobrietyDate =
            profile['sobriety_date'];

        final sobrietyDate =
            rawSobrietyDate?.toString();

        final displayDate = (
          sobrietyDate == null ||
          sobrietyDate.isEmpty
        )
            ? 'Not set'
            : sobrietyDate;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Profile',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium,
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sobriety Date',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      displayDate,
                      key: const ValueKey(
                        'profile-sobriety-date',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge,
                    ),

                    const SizedBox(height: 16),

                    FilledButton.icon(
                      key: const ValueKey(
                        'profile-change-sobriety-date',
                      ),
                      onPressed: _saving
                          ? null
                          : () {
                              _chooseSobrietyDate(
                                sobrietyDate,
                              );
                            },
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.calendar_today_outlined,
                            ),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : (
                                sobrietyDate == null ||
                                sobrietyDate.isEmpty
                              )
                                ? 'Set Sobriety Date'
                                : 'Change Sobriety Date',
                      ),
                    ),

                    if (_saveError != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _saveError!,
                        key: const ValueKey(
                          'profile-save-error',
                        ),
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
