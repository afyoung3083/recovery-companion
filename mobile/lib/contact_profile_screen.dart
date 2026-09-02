import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'beta_support_action.dart';
import 'local_fellowship_repository.dart';

class ContactProfileScreen extends StatefulWidget {
  const ContactProfileScreen({
    required this.apiClient,
    required this.contact,
    this.localRepository,
    super.key,
  });

  final ApiClient apiClient;
  final Map<String, dynamic> contact;
  final LocalFellowshipRepository? localRepository;

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  static const List<String> _contactTypes = [
    'sponsor',
    'sponsee',
    'dsr',
    'fellowship',
    'therapist',
    'clergy',
    'family',
    'other',
  ];

  late final TextEditingController _handleController;
  late final TextEditingController _contactMethodController;
  late final TextEditingController _notesController;

  late String _contactType;
  late bool _active;
  late bool _originalActive;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _handleController = TextEditingController(
      text: (widget.contact['handle'] ?? '').toString(),
    );

    _contactMethodController = TextEditingController(
      text: (widget.contact['contact_method'] ?? '').toString(),
    );

    _notesController = TextEditingController(
      text: (widget.contact['notes'] ?? '').toString(),
    );

    final rawType = (widget.contact['contact_type'] ?? 'other')
        .toString()
        .toLowerCase();

    _contactType = _contactTypes.contains(rawType) ? rawType : 'other';

    _active = widget.contact['active'] != false;
    _originalActive = _active;
  }

  @override
  void dispose() {
    _handleController.dispose();
    _contactMethodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final contactId = widget.contact['id'];

    final handle = _handleController.text.trim();

    if (contactId is! int) {
      setState(() {
        _error =
            'This contact cannot be updated because its identifier is missing.';
      });
      return;
    }

    if (handle.isEmpty) {
      setState(() {
        _error = 'Name or handle is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final localRepository = widget.localRepository;

      if (localRepository != null) {
        await localRepository.updateContact(
          contactId: contactId,
          handle: handle,
          contactType: _contactType,
          contactMethod: _contactMethodController.text.trim(),
          notes: _notesController.text.trim(),
        );

        if (_active != _originalActive) {
          await localRepository.setContactActive(
            contactId: contactId,
            active: _active,
          );
        }
      } else {
        await widget.apiClient.updateFellowshipContact(
          contactId: contactId,
          handle: handle,
          contactType: _contactType,
          contactMethod: _contactMethodController.text.trim(),
          notes: _notesController.text.trim(),
        );

        if (_active != _originalActive) {
          await widget.apiClient.setFellowshipContactActive(
            contactId: contactId,
            active: _active,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _originalActive = _active;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contact profile saved.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to save this contact profile. Please try again.';
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
    final displayName = _handleController.text.trim().isEmpty
        ? 'Recovery contact'
        : _handleController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Profile'),
        actions: const [BetaSupportAction()],
      ),
      body: ListView(
        key: const ValueKey('contact-profile-screen'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          AppPageHeader(
            title: displayName,
            subtitle: 'Your private recovery contact record.',
            icon: Icons.person_outline,
          ),

          const AppSectionTitle(
            title: 'Contact',
            subtitle: 'Keep the details that help you stay connected.',
          ),

          AppSectionCard(
            child: Column(
              children: [
                TextField(
                  key: const ValueKey('contact-profile-handle'),
                  controller: _handleController,
                  decoration: const InputDecoration(
                    labelText: 'Name or handle',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),

                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  key: const ValueKey('contact-profile-type'),
                  initialValue: _contactType,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    prefixIcon: Icon(Icons.people_outline),
                  ),
                  items: _contactTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_displayContactType(type)),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _contactType = value;
                          });
                        },
                ),

                const SizedBox(height: 14),

                TextField(
                  key: const ValueKey('contact-profile-method'),
                  controller: _contactMethodController,
                  decoration: const InputDecoration(
                    labelText: 'Contact method',
                    hintText: 'Phone, email, Signal, etc.',
                    prefixIcon: Icon(Icons.contact_phone_outlined),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  key: const ValueKey('contact-profile-notes'),
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Meeting connection, sponsor direction, useful reminders...',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const AppSectionTitle(title: 'Connection Status'),

          AppSectionCard(
            child: SwitchListTile(
              key: const ValueKey('contact-profile-active-switch'),
              contentPadding: EdgeInsets.zero,
              value: _active,
              title: Text(_active ? 'Active contact' : 'Inactive contact'),
              subtitle: Text(
                _active
                    ? 'This person can appear in Fellowship recommendations.'
                    : 'This person stays in your records but is excluded from recommendations.',
              ),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _active = value;
                      });
                    },
            ),
          ),

          const SizedBox(height: 24),

          const AppSectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This is your private recovery record. Recovery Companion does not contact this person automatically.',
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            AppStatusMessage(
              title: 'Unable to save contact',
              message: _error!,
              icon: Icons.error_outline,
            ),
          ],

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('contact-profile-save'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_outlined),
              label: Text(_saving ? 'Saving...' : 'Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  static String _displayContactType(String type) {
    if (type == 'dsr') {
      return 'DSR';
    }

    if (type.isEmpty) {
      return 'Other';
    }

    return '${type[0].toUpperCase()}'
        '${type.substring(1)}';
  }
}
