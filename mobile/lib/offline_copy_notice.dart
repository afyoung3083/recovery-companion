import 'package:flutter/material.dart';

import 'app_components.dart';

class OfflineCopyNotice extends StatelessWidget {
  const OfflineCopyNotice({
    required this.cachedAt,
    required this.onRetry,
    this.detail,
    super.key,
  });

  final DateTime? cachedAt;
  final VoidCallback onRetry;
  final String? detail;

  String _cachedAtText(BuildContext context, DateTime cachedAt) {
    final local = cachedAt.toLocal();
    final localizations = MaterialLocalizations.of(context);

    final date = localizations.formatMediumDate(local);

    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));

    return '$date at $time';
  }

  @override
  Widget build(BuildContext context) {
    final cachedText = cachedAt == null
        ? ''
        : ' on ${_cachedAtText(context, cachedAt!)}';

    final detailText = detail == null || detail!.trim().isEmpty
        ? ''
        : ' ${detail!.trim()}';

    return AppStatusMessage(
      title: 'Offline copy',
      message:
          'Showing the most recent encrypted copy '
          'saved on this device$cachedText. '
          'Some information may be out of date.'
          '$detailText',
      icon: Icons.cloud_off_outlined,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}
