import 'package:flutter/material.dart';

import 'api_client.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({
    required this.apiClient,
    super.key,
  });

  final ApiClient apiClient;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late Future<Map<String, dynamic>> _entriesFuture;

  final TextEditingController _entryController =
      TextEditingController();

  final TextEditingController _tagsController =
      TextEditingController();

  final TextEditingController _searchController =
      TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.apiClient.getJournalEntries();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _tagsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadAll() {
    setState(() {
      _error = null;
      _entriesFuture = widget.apiClient.getJournalEntries();
    });
  }

  void _search() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _loadAll();
      return;
    }

    setState(() {
      _error = null;
      _entriesFuture = widget.apiClient.searchJournal(
        query,
      );
    });
  }

  Future<void> _saveEntry() async {
    final text = _entryController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _error = 'Journal entry cannot be empty.';
      });

      return;
    }

    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.apiClient.createJournalEntry(
        text: text,
        tags: tags,
      );

      if (!mounted) {
        return;
      }

      _entryController.clear();
      _tagsController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Journal entry saved.',
          ),
        ),
      );

      _loadAll();
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Journal',
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _entryController,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'New journal entry',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _tagsController,
          decoration: const InputDecoration(
            labelText: 'Tags',
            hintText: 'connection, sponsor, gratitude',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 12),

        FilledButton.icon(
          onPressed: _saving
              ? null
              : _saveEntry,
          icon: const Icon(
            Icons.save_outlined,
          ),
          label: Text(
            _saving
                ? 'Saving...'
                : 'Save Journal Entry',
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .error,
            ),
          ),
        ],

        const SizedBox(height: 28),

        Text(
          'Journal History',
          style: Theme.of(context)
              .textTheme
              .titleLarge,
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search text or tags',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _search();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _search,
              tooltip: 'Search',
              icon: const Icon(
                Icons.search,
              ),
            ),
            IconButton(
              onPressed: () {
                _searchController.clear();
                _loadAll();
              },
              tooltip: 'Clear search',
              icon: const Icon(
                Icons.clear,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        FutureBuilder<Map<String, dynamic>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (
                snapshot.connectionState ==
                ConnectionState.waiting
            ) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  snapshot.error.toString(),
                ),
              );
            }

            final data = snapshot.data ?? const {};
            final rawEntries = data['entries'];

            final entries = rawEntries is List
                ? rawEntries
                    .whereType<Map<String, dynamic>>()
                    .toList()
                : <Map<String, dynamic>>[];

            if (entries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No journal entries found.',
                  ),
                ),
              );
            }

            return Column(
              children: entries.map((entry) {
                final text = (
                  entry['text'] ??
                  ''
                ).toString();

                final date = (
                  entry['date'] ??
                  entry['created_at'] ??
                  ''
                ).toString();

                final rawTags = entry['tags'];

                final tags = rawTags is List
                    ? rawTags
                        .map((tag) => tag.toString())
                        .toList()
                    : <String>[];

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium,
                          ),
                        if (date.isNotEmpty)
                          const SizedBox(
                            height: 8,
                          ),
                        Text(
                          text,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge,
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(
                            height: 12,
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags
                                .map(
                                  (tag) => Chip(
                                    label: Text(tag),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}