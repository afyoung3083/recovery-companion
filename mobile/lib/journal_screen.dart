import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_components.dart';
import 'offline_copy_notice.dart';
import 'offline_read_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({
    required this.apiClient,
    this.offlineReadService,
    super.key,
  });

  final ApiClient apiClient;
  final OfflineReadService? offlineReadService;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late Future<OfflineReadResult> _entriesFuture;

  final TextEditingController _entryController = TextEditingController();

  final TextEditingController _tagsController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();

  bool _saving = false;
  bool _showingOfflineCopy = false;
  int? _analyzingEntryId;
  int? _reflectionEntryId;
  String? _reflection;
  String? _error;

  Future<OfflineReadResult> _loadJournalEntries() async {
    final service = widget.offlineReadService;

    late final OfflineReadResult result;

    if (service == null) {
      final data = await widget.apiClient.getJournalEntries();

      result = OfflineReadResult(data: data, source: OfflineReadSource.network);
    } else {
      result = await service.read(
        cacheKey: OfflineCacheKeys.journal,
        networkRead: widget.apiClient.getJournalEntries,
      );
    }

    if (mounted && _showingOfflineCopy != result.isCached) {
      setState(() {
        _showingOfflineCopy = result.isCached;
      });
    }

    return result;
  }

  Future<OfflineReadResult> _searchJournal(String query) async {
    final data = await widget.apiClient.searchJournal(query);

    _showingOfflineCopy = false;

    return OfflineReadResult(data: data, source: OfflineReadSource.network);
  }

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadJournalEntries();
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
      _showingOfflineCopy = false;
      _entriesFuture = _loadJournalEntries();
    });
  }

  Future<void> _refresh() async {
    final future = _loadJournalEntries();

    setState(() {
      _error = null;
      _showingOfflineCopy = false;
      _entriesFuture = future;
    });

    await future;
  }

  void _search() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _loadAll();
      return;
    }

    if (_showingOfflineCopy) {
      return;
    }

    setState(() {
      _error = null;
      _showingOfflineCopy = false;
      _entriesFuture = _searchJournal(query);
    });
  }

  Future<void> _saveEntry() async {
    final text = _entryController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _error = 'Write something before saving this journal entry.';
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
      await widget.apiClient.createJournalEntry(text: text, tags: tags);

      if (!mounted) {
        return;
      }

      _entryController.clear();
      _tagsController.clear();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Journal entry saved.')));

      _loadAll();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to save this journal entry. Please try again.';
        });
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
    });
  }

  Future<void> _analyzeEntry({required int entryId}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Analyze this journal entry?'),
          content: const Text(
            'Only this selected journal entry will be sent to the AI '
            'for an optional recovery reflection. The reflection is '
            'not saved automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Analyze Entry'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _analyzingEntryId = entryId;
      _reflectionEntryId = null;
      _reflection = null;
      _error = null;
    });

    try {
      final response = await widget.apiClient.analyzeJournalEntry(entryId);

      if (!mounted) {
        return;
      }

      final reflection = (response['reflection'] ?? '').toString().trim();

      setState(() {
        _reflectionEntryId = entryId;
        _reflection = reflection.isEmpty
            ? 'No AI reflection was returned.'
            : reflection;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to generate a journal reflection. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _analyzingEntryId = null;
        });
      }
    }
  }

  List<Map<String, dynamic>> _entriesFrom(Map<String, dynamic>? data) {
    final rawEntries = data?['entries'];

    if (rawEntries is! List) {
      return [];
    }

    return rawEntries.whereType<Map<String, dynamic>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const AppPageHeader(
            title: 'Journal',
            subtitle: 'Write what is true, notice what matters, and return to it later.',
            icon: Icons.menu_book_outlined,
          ),

          const AppSectionTitle(
            title: 'New Entry',
            subtitle: 'This journal stays part of your recovery record.',
          ),

          AppSectionCard(
            key: const ValueKey('journal-entry-composer'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _entryController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'What is on your mind?',
                    hintText: 'Write freely about what happened, what you felt, what you noticed, or what you need to remember...',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (optional)',
                    hintText: 'connection, sponsor, gratitude',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('journal-save-entry'),
                    onPressed: _saving ? null : _saveEntry,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Entry'),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            AppStatusMessage(
              title: 'Journal action unavailable',
              message: _error!,
              icon: Icons.error_outline,
            ),
          ],

          const SizedBox(height: 28),

          const AppSectionTitle(
            title: 'Journal History',
            subtitle: 'Search your entries or revisit what you have written.',
          ),

          AppSectionCard(
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  enabled: !_showingOfflineCopy,
                  decoration: InputDecoration(
                    labelText: 'Search journal',
                    hintText: 'Search text or tags',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _loadAll();
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                  onSubmitted: (_) {
                    _search();
                  },
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showingOfflineCopy ? null : _search,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'AI reflection is optional. Only an entry you explicitly select for analysis is sent to the AI.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          FutureBuilder<OfflineReadResult>(
            future: _entriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return AppStatusMessage(
                  title: 'Unable to load journal',
                  message:
                      'Recovery Companion could not load your journal entries.',
                  icon: Icons.cloud_off_outlined,
                  actionLabel: 'Retry',
                  onAction: _loadAll,
                );
              }

              final readResult = snapshot.data!;
              final entries = _entriesFrom(readResult.data);

              return Column(
                children: [
                  if (readResult.isCached) ...[
                    OfflineCopyNotice(
                      cachedAt: readResult.cachedAt,
                      onRetry: _loadAll,
                      detail:
                          'Saving, online search, and AI '
                          'reflection still require a connection.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (entries.isEmpty)
                    const AppStatusMessage(
                      title: 'No journal entries found',
                      message:
                          'Write a new entry above, or clear '
                          'your search to see all entries.',
                      icon: Icons.menu_book_outlined,
                    )
                  else
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _JournalEntryCard(
                          entry: entry,
                          analyzing: _analyzingEntryId == entry['id'],
                          reflection: _reflectionEntryId == entry['id']
                              ? _reflection
                              : null,
                          canAnalyze:
                              !readResult.isCached && _analyzingEntryId == null,
                          onAnalyze: (entryId) {
                            _analyzeEntry(entryId: entryId);
                          },
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({
    required this.entry,
    required this.analyzing,
    required this.reflection,
    required this.canAnalyze,
    required this.onAnalyze,
  });

  final Map<String, dynamic> entry;
  final bool analyzing;
  final String? reflection;
  final bool canAnalyze;
  final ValueChanged<int> onAnalyze;

  @override
  Widget build(BuildContext context) {
    final id = entry['id'];

    final text = (entry['text'] ?? '').toString();

    final date = (entry['date'] ?? entry['created_at'] ?? '').toString();

    final rawTags = entry['tags'];

    final tags = rawTags is List
        ? rawTags.map((tag) => tag.toString()).toList()
        : <String>[];

    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.isEmpty ? 'Journal Entry' : date,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in tags)
                            Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SelectableText(
            text,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(height: 1.45),
          ),

          if (id is int) ...[
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ValueKey('journal-ai-$id'),
                onPressed: canAnalyze
                    ? () {
                        onAnalyze(id);
                      }
                    : null,
                icon: analyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  analyzing ? 'Generating Reflection...' : 'Reflect with AI',
                ),
              ),
            ),
          ],

          if (reflection != null) ...[
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recovery Companion Reflection',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    reflection!,
                    key: const ValueKey('journal-ai-reflection'),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
