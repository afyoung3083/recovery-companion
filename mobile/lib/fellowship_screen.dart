import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'contact_profile_screen.dart';

class FellowshipScreen extends StatefulWidget {
  const FellowshipScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<FellowshipScreen> createState() => _FellowshipScreenState();
}

class _FellowshipScreenState extends State<FellowshipScreen> {
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

  final TextEditingController _handleController = TextEditingController();

  final TextEditingController _contactMethodController =
      TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  late Future<Map<String, dynamic>> _contactsFuture;

  late Future<Map<String, dynamic>> _recommendedFuture;

  String _contactType = 'fellowship';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _handleController.dispose();
    _contactMethodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _error = null;

      _contactsFuture = widget.apiClient.getFellowshipContacts();

      _recommendedFuture = widget.apiClient.getRecommendedFellowshipContacts();
    });
  }

  Future<void> _refresh() async {
    final contacts = widget.apiClient.getFellowshipContacts();

    final recommended = widget.apiClient.getRecommendedFellowshipContacts();

    setState(() {
      _error = null;
      _contactsFuture = contacts;
      _recommendedFuture = recommended;
    });

    await Future.wait([contacts, recommended]);
  }

  Future<void> _openContact(Map<String, dynamic> contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ContactProfileScreen(apiClient: widget.apiClient, contact: contact),
      ),
    );

    if (mounted) {
      _loadData();
    }
  }

  Future<void> _addContact() async {
    final handle = _handleController.text.trim();

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
      await widget.apiClient.createFellowshipContact(
        handle: handle,
        contactType: _contactType,
        contactMethod: _contactMethodController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      _handleController.clear();
      _contactMethodController.clear();
      _notesController.clear();

      setState(() {
        _contactType = 'fellowship';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fellowship contact added.')),
      );

      _loadData();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to add this fellowship contact. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _contactsFrom(Map<String, dynamic>? response) {
    final rawContacts = response?['contacts'];

    if (rawContacts is! List) {
      return [];
    }

    return rawContacts.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const AppPageHeader(
            title: 'Fellowship',
            subtitle: 'Keep your recovery support network close.',
            icon: Icons.groups_outlined,
          ),

          const AppSectionTitle(
            title: 'Stay Connected',
            subtitle: 'People Recovery Companion may surface when connection could help.',
          ),

          FutureBuilder<Map<String, dynamic>>(
            future: _recommendedFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return AppStatusMessage(
                  title: 'Unable to load recommendations',
                  message:
                      'Recovery Companion could not load recommended contacts.',
                  icon: Icons.cloud_off_outlined,
                  actionLabel: 'Retry',
                  onAction: _loadData,
                );
              }

              final contacts = _contactsFrom(snapshot.data);

              if (contacts.isEmpty) {
                return const AppStatusMessage(
                  title: 'No recommended contacts yet',
                  message: 'Add active fellowship contacts and recommendations will appear here.',
                  icon: Icons.people_outline,
                );
              }

              return AppSectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0; index < contacts.length; index++) ...[
                      _ContactTile(
                        contact: contacts[index],
                        emphasized: index == 0,
                        onTap: () {
                          _openContact(contacts[index]);
                        },
                      ),
                      if (index < contacts.length - 1)
                        const Divider(height: 1, indent: 68),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'Add a Contact',
            subtitle:
                'Save someone who is part of your recovery support network.',
          ),

          AppSectionCard(
            key: const ValueKey('fellowship-add-card'),
            child: Column(
              children: [
                TextField(
                  controller: _handleController,
                  decoration: const InputDecoration(
                    labelText: 'Name or handle',
                    prefixIcon: Icon(Icons.person_add_outlined),
                  ),
                ),

                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
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
                  controller: _contactMethodController,
                  decoration: const InputDecoration(
                    labelText: 'Contact method',
                    hintText: 'Phone, email, etc.',
                    prefixIcon: Icon(Icons.contact_phone_outlined),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _addContact,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_outlined),
                    label: Text(_saving ? 'Saving...' : 'Add Contact'),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            AppStatusMessage(
              title: 'Fellowship action unavailable',
              message: _error!,
              icon: Icons.error_outline,
            ),
          ],

          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'All Contacts',
            subtitle: 'Open a contact to edit details or change whether they are active.',
          ),

          FutureBuilder<Map<String, dynamic>>(
            future: _contactsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return AppStatusMessage(
                  title: 'Unable to load contacts',
                  message: 'Recovery Companion could not load your fellowship contacts.',
                  icon: Icons.cloud_off_outlined,
                  actionLabel: 'Retry',
                  onAction: _loadData,
                );
              }

              final contacts = _contactsFrom(snapshot.data);

              if (contacts.isEmpty) {
                return const AppStatusMessage(
                  title: 'No fellowship contacts yet',
                  message: 'Add a person above when you are ready.',
                  icon: Icons.people_outline,
                );
              }

              return AppSectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0; index < contacts.length; index++) ...[
                      _ContactTile(
                        contact: contacts[index],
                        onTap: () {
                          _openContact(contacts[index]);
                        },
                      ),
                      if (index < contacts.length - 1)
                        const Divider(height: 1, indent: 68),
                    ],
                  ],
                ),
              );
            },
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

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onTap,
    this.emphasized = false,
  });

  final Map<String, dynamic> contact;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final handle = (contact['handle'] ?? 'Recovery contact').toString();

    final type = _FellowshipScreenState._displayContactType(
      (contact['contact_type'] ?? 'other').toString(),
    );

    final method = (contact['contact_method'] ?? '').toString().trim();

    final active = contact['active'] != false;

    return ListTile(
      key: ValueKey('fellowship-contact-${contact['id']}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: emphasized
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          emphasized
              ? Icons.star_outline
              : active
              ? Icons.person_outline
              : Icons.person_off_outlined,
        ),
      ),
      title: Text(handle, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(method.isEmpty ? type : '$type ? $method'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
