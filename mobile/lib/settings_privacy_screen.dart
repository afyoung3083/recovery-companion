import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'app_components.dart';

class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  static const _deletePhrase = 'DELETE MY RECOVERY DATA';

  final _deleteController = TextEditingController();

  bool _isExporting = false;
  bool _isDeleting = false;

  String? _exportJson;
  String? _exportCreatedAt;
  String? _exportHash;

  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _deleteController.addListener(_refreshDeleteState);
  }

  @override
  void dispose() {
    _deleteController.removeListener(_refreshDeleteState);
    _deleteController.dispose();
    super.dispose();
  }

  void _refreshDeleteState() {
    setState(() {});
  }

  Future<void> _prepareExport() async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      final response = await widget.apiClient.exportRecoveryData();

      final export = Map<String, dynamic>.from(response['export'] as Map);

      final metadata = Map<String, dynamic>.from(
        export['metadata'] as Map? ?? const {},
      );

      const encoder = JsonEncoder.withIndent('  ');

      if (!mounted) {
        return;
      }

      setState(() {
        _exportJson = encoder.convert(export);
        _exportCreatedAt = metadata['created_at']?.toString();
        _exportHash = metadata['sha256']?.toString();

        _statusMessage = 'Your recovery data export is ready.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Unable to prepare your recovery data export. '
            'Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _copyExport() async {
    final exportJson = _exportJson;

    if (exportJson == null) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: exportJson));

    if (!mounted) {
      return;
    }

    setState(() {
      _statusMessage = 'Export copied to the system clipboard.';
      _errorMessage = null;
    });
  }

  Future<void> _confirmDeletion() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Permanently delete recovery data?'),
          content: const Text(
            'This removes your active Recovery Companion '
            'recovery records and Recovery Companion-created '
            'backup files. This cannot be undone unless you '
            'already saved an export somewhere else.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-permanent-delete'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete permanently'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    await _deleteRecoveryData();
  }

  Future<void> _deleteRecoveryData() async {
    setState(() {
      _isDeleting = true;
      _statusMessage = null;
      _errorMessage = null;
    });

    try {
      await widget.apiClient.deleteRecoveryData(confirmation: _deletePhrase);

      if (!mounted) {
        return;
      }

      _deleteController.clear();

      setState(() {
        _exportJson = null;
        _exportCreatedAt = null;
        _exportHash = null;
        _statusMessage = 'Recovery data was permanently deleted.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Unable to delete recovery data. '
            'Your data was not intentionally changed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deleteEnabled =
        _deleteController.text == _deletePhrase && !_isDeleting;

    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const AppPageHeader(
          title: 'Settings & Privacy',
          subtitle:
              'Control your recovery data and '
              'understand when AI is involved.',
          icon: Icons.privacy_tip_outlined,
        ),

        if (_statusMessage != null) ...[
          AppStatusMessage(
            title: _statusMessage!,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 20),
        ],

        if (_errorMessage != null) ...[
          AppStatusMessage(
            title: 'Something went wrong',
            message: _errorMessage,
            icon: Icons.error_outline,
          ),
          const SizedBox(height: 20),
        ],

        const AppSectionTitle(
          title: 'Your recovery data',
          subtitle: 'You control your Recovery Companion records.',
        ),

        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InfoRow(
                icon: Icons.storage_outlined,
                title: 'Recovery records',
                text:
                    'Core recovery records are kept in '
                    'Recovery Companion\'s local application '
                    'data store.',
              ),
              const SizedBox(height: 18),
              const _InfoRow(
                icon: Icons.verified_user_outlined,
                title: 'User-controlled export',
                text:
                    'You can request a complete export of '
                    'your profile, journal, Step Work, '
                    'fellowship, check-ins, reviews, goals, '
                    'and routines.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('prepare-data-export'),
                  onPressed: _isExporting ? null : _prepareExport,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(
                    _isExporting
                        ? 'Preparing export...'
                        : 'Prepare Recovery Data Export',
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_exportJson != null) ...[
          const SizedBox(height: 16),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export ready',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_exportCreatedAt != null) ...[
                  const SizedBox(height: 6),
                  Text('Created: $_exportCreatedAt'),
                ],
                if (_exportHash != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Integrity hash: $_exportHash',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Copying places sensitive recovery data '
                  'on the system clipboard until it is '
                  'replaced.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const ValueKey('copy-data-export'),
                  onPressed: _copyExport,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy Export JSON'),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        const AppSectionTitle(
          title: 'AI & privacy',
          subtitle: 'AI support remains user-directed.',
        ),

        const AppSectionCard(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.touch_app_outlined,
                title: 'AI reflection is optional',
                text:
                    'Journal, Daily Recovery, Recovery '
                    'Insights, Weekly Review, and Monthly '
                    'Review send recovery information for AI '
                    'reflection only when you explicitly '
                    'request that feature.',
              ),
              SizedBox(height: 18),
              _InfoRow(
                icon: Icons.chat_bubble_outline,
                title: 'Recovery Companion chat',
                text:
                    'Chat sends the current conversation so '
                    'the companion can respond in context. '
                    'The API does not automatically persist '
                    'the chat conversation.',
              ),
              SizedBox(height: 18),
              _InfoRow(
                icon: Icons.groups_outlined,
                title: 'Human relationships come first',
                text:
                    'AI is designed to support, not replace, '
                    'your sponsor, fellowship, therapist, '
                    'clergy, or other trusted people.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        AppSectionTitle(
          title: 'Danger zone',
          subtitle:
              'Permanent deletion removes Recovery '
              'Companion-owned recovery records and backups.',
          titleColor: scheme.error,
        ),

        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete Recovery Data',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.error,
                ),
              ),
              const SizedBox(height: 8),
              const Text('To enable deletion, type the exact phrase:'),
              const SizedBox(height: 8),
              SelectableText(
                _deletePhrase,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('delete-confirmation-field'),
                controller: _deleteController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Confirmation phrase',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('delete-recovery-data'),
                  onPressed: deleteEnabled ? _confirmDeletion : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: Text(
                    _isDeleting ? 'Deleting...' : 'Delete Recovery Data',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(text),
            ],
          ),
        ),
      ],
    );
  }
}
