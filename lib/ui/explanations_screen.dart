import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_strings.dart';
import '../data/models.dart';
import '../state/app_state.dart';

/// Lists every saved answer explanation (English / Hindi), with search and
/// in-place editing.
class ExplanationsScreen extends StatefulWidget {
  const ExplanationsScreen({super.key});

  @override
  State<ExplanationsScreen> createState() => _ExplanationsScreenState();
}

class _ExplanationsScreenState extends State<ExplanationsScreen> {
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  String _language = 'en';
  String _query = '';

  @override
  void initState() {
    super.initState();
    final profileLanguage = AppText.read(context).language;
    _language = profileLanguage == 'hi' ? 'hi' : 'en';
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    await state.loadExplanationEntries(language: _language);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _changeLanguage(String language) async {
    if (language == _language) return;
    setState(() {
      _language = language;
      _loading = true;
    });
    await _load();
  }

  List<ExplanationEntry> _visibleEntries(AppState state) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return state.explanationEntries;
    return state.explanationEntries.where((entry) {
      return entry.question.text.toLowerCase().contains(query) ||
          entry.question.number.toLowerCase().contains(query) ||
          entry.explanation.explanation.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _edit(AppState state, ExplanationEntry entry) async {
    final t = AppText.read(context);
    final controller = TextEditingController(
      text: entry.explanation.explanation,
    );
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.editExplanation),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            autofocus: true,
            decoration: InputDecoration(
              labelText: t.answerExplanations,
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(dialogContext).pop(text);
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
    controller.dispose();

    if (updated == null) return;
    if (updated.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.explanationRequired)));
      return;
    }

    await state.updateExplanation(
      entry.explanation.copyWith(explanation: updated, source: 'user'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t.explanationSaved)));
  }

  Future<void> _delete(AppState state, ExplanationEntry entry) async {
    final t = AppText.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.delete),
        content: Text(t.deleteExplanationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await state.deleteExplanation(entry.explanation.id);
  }

  void _showDetails(AppState state, ExplanationEntry entry) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = AppText.read(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                entry.question.number,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.questionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.question.text,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (entry.question.options.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final option in entry.question.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '${option.label}) ${option.text}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
                const Divider(height: 24),
                Text(
                  entry.explanation.explanation,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                if ((entry.explanation.source ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${t.sourceLabel}: ${entry.explanation.source}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _delete(state, entry);
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(t.delete),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _edit(state, entry);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(t.edit),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final t = AppText.of(context);
    final entries = _visibleEntries(state);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.answerExplanations),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${t.languageLabel}:',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          ChoiceChip(
                            label: Text(t.english),
                            selected: _language == 'en',
                            onSelected: (_) => _changeLanguage('en'),
                          ),
                          ChoiceChip(
                            label: Text(t.hindi),
                            selected: _language == 'hi',
                            onSelected: (_) => _changeLanguage('hi'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: t.searchExplanationsHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? _EmptyExplanations(t: t)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: entries.length,
                            itemBuilder: (_, index) {
                              final entry = entries[index];
                              return _ExplanationCard(
                                entry: entry,
                                t: t,
                                onTap: () => _showDetails(state, entry),
                                onEdit: () => _edit(state, entry),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _EmptyExplanations extends StatelessWidget {
  const _EmptyExplanations({required this.t});

  final AppText t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 56),
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 64,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          t.noExplanationsTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          t.noExplanationsBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({
    required this.entry,
    required this.t,
    required this.onTap,
    required this.onEdit,
  });

  final ExplanationEntry entry;
  final AppText t;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    entry.question.number,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.question.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.explanation.explanation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.language_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.explanation.language == 'hi'
                              ? t.hindi
                              : t.english,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if ((entry.explanation.source ?? '').isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Text(
                            entry.explanation.source!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.edit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
