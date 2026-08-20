import 'package:flutter/material.dart';

import 'api_client.dart';

class FellowshipScreen extends StatefulWidget {
  const FellowshipScreen({
    required this.apiClient,
    super.key,
  });

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

  final TextEditingController _handleController =
      TextEditingController();
  final TextEditingController _contactMethodController =
      TextEditingController();
  final TextEditingController _notesController =
      TextEditingController();

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
      _contactsFuture =
          widget.apiClient.getFellowshipContacts();
      _recommendedFuture =
          widget.apiClient.getRecommendedFellowshipContacts();
    });
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
        const SnackBar(
          content: Text(
            'Fellowship contact added.',
          ),
        ),
      );

      _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _setActive({
    required int contactId,
    required bool active,
  }) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.apiClient.setFellowshipContactActive(
        contactId: contactId,
        active: active,
      );

      if (!mounted) {
        return;
      }

      _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _contactsFrom(
    Map<String, dynamic>? response,
  ) {
    final rawContacts = response?['contacts'];

    if (rawContacts is! List) {
      return [];
    }

    return rawContacts
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Fellowship',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Keep your recovery support network close.',
        ),
        const SizedBox(height: 24),

        Text(
          'Recommended Contacts',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        FutureBuilder<Map<String, dynamic>>(
          future: _recommendedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                snapshot.error.toString(),
              );
            }

            final contacts = _contactsFrom(snapshot.data);

            if (contacts.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No recommended contacts yet.',
                  ),
                ),
              );
            }

            return Column(
              children: contacts
                  .map(
                    (contact) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.star_outline,
                        ),
                        title: Text(
                          (contact['handle'] ?? '').toString(),
                        ),
                        subtitle: Text(
                          _contactDescription(contact),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),

        const SizedBox(height: 24),

        Text(
          'Add Contact',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _handleController,
          decoration: const InputDecoration(
            labelText: 'Name or handle',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          initialValue: _contactType,
          decoration: const InputDecoration(
            labelText: 'Contact type',
            border: OutlineInputBorder(),
          ),
          items: _contactTypes
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(
                    _displayContactType(type),
                  ),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _contactType = value;
                    });
                  }
                },
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _contactMethodController,
          decoration: const InputDecoration(
            labelText: 'Contact method',
            hintText: 'Phone, email, etc.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        FilledButton.icon(
          onPressed: _saving ? null : _addContact,
          icon: const Icon(
            Icons.person_add_outlined,
          ),
          label: const Text(
            'Add Contact',
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],

        const SizedBox(height: 28),

        Text(
          'All Contacts',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        FutureBuilder<Map<String, dynamic>>(
          future: _contactsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                snapshot.error.toString(),
              );
            }

            final contacts = _contactsFrom(snapshot.data);

            if (contacts.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No fellowship contacts yet.',
                  ),
                ),
              );
            }

            return Column(
              children: contacts
                  .map(
                    (contact) => _buildContactCard(
                      contact,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContactCard(
    Map<String, dynamic> contact,
  ) {
    final id = contact['id'] as int?;
    final active = contact['active'] != false;

    return Card(
      child: ListTile(
        leading: Icon(
          active
              ? Icons.person_outline
              : Icons.person_off_outlined,
        ),
        title: Text(
          (contact['handle'] ?? '').toString(),
        ),
        subtitle: Text(
          _contactDescription(contact),
        ),
        trailing: Switch(
          value: active,
          onChanged: _saving || id == null
              ? null
              : (value) {
                  _setActive(
                    contactId: id,
                    active: value,
                  );
                },
        ),
      ),
    );
  }

  String _contactDescription(
    Map<String, dynamic> contact,
  ) {
    final type = _displayContactType(
      (contact['contact_type'] ?? 'other').toString(),
    );

    final method =
        (contact['contact_method'] ?? '').toString().trim();

    final notes =
        (contact['notes'] ?? '').toString().trim();

    final parts = <String>[
      type,
    ];

    if (method.isNotEmpty) {
      parts.add(method);
    }

    if (notes.isNotEmpty) {
      parts.add(notes);
    }

    return parts.join(' • ');
  }

  static String _displayContactType(
    String type,
  ) {
    if (type == 'dsr') {
      return 'DSR';
    }

    if (type.isEmpty) {
      return 'Other';
    }

    return '${type[0].toUpperCase()}${type.substring(1)}';
  }
}