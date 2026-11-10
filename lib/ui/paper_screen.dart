import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../core/models.dart';
import '../data/models.dart';
import 'question_edit_sheet.dart';
import 'question_table.dart';

enum _PaperAction { rename, rawText, delete }

enum _QuestionFilter {
  all('All'),
  review('Needs review'),
  mcq('MCQ');

  const _QuestionFilter(this.label);
  final String label;
}

/// Shows one imported paper: its summary, warnings and the question table.
class PaperScreen extends StatefulWidget {
  const PaperScreen({super.key, required this.paperId});

  final int paperId;

  @override
  State<PaperScreen> createState() => _PaperScreenState();
}

class _PaperScreenState extends State<PaperScreen> {
  final TextEditingController _search = TextEditingController();

  PaperDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _started = false;
  _QuestionFilter _filter = _QuestionFilter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final detail = await AppScope.read(context).loadPaper(widget.paperId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        if (detail == null) {
          _error = 'This paper no longer exists.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<StoredQuestion> get _visibleQuestions {
    final detail = _detail;
    if (detail == null) return const [];

    final query = _search.text.trim().toLowerCase();
    return detail.questions.where((question) {
      if (_filter == _QuestionFilter.review && !question.needsReview) {
        return false;
      }
      if (_filter == _QuestionFilter.mcq && !question.isMultipleChoice) {
        return false;
      }
      if (query.isEmpty) return true;

      return question.text.toLowerCase().contains(query) ||
          question.number.toLowerCase().contains(query) ||
          question.section.toLowerCase().contains(query) ||
          question.options
              .any((option) => option.text.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _editQuestion(StoredQuestion question) async {
    final updated = await showQuestionEditSheet(context, question);
    if (updated == null || !mounted) return;

    try {
      await AppScope.read(context).saveQuestion(updated);
      await _load();
    } catch (error) {
      _snack('Could not save the question: $error');
    }
  }

  Future<void> _export() async {
    final detail = _detail;
    if (detail == null) return;
    try {
      await AppScope.read(context).exportPaper(detail);
    } catch (error) {
      _snack('Could not export this paper: $error');
    }
  }

  Future<void> _rename() async {
    final detail = _detail;
    if (detail == null) return;

    var draft = detail.paper.title;
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename paper'),
        content: TextFormField(
          initialValue: detail.paper.title,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Paper title'),
          onChanged: (value) => draft = value,
          onFieldSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(draft),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (title == null || !mounted) return;
    try {
      await AppScope.read(context).renamePaper(detail.paper.id, title);
      await _load();
    } catch (error) {
      _snack('Could not rename this paper: $error');
    }
  }

  Future<void> _delete() async {
    final detail = _detail;
    if (detail == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete paper?'),
        content: Text(
          'This permanently removes "${detail.paper.title}" and all '
          '${detail.questions.length} extracted questions. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await AppScope.read(context).deletePaper(detail.paper.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _snack('Could not delete this paper: $error');
    }
  }

  void _showRawText() {
    final detail = _detail;
    if (detail == null) return;
    final text = detail.paper.rawText.trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Extracted text',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy all',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: text.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: text));
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Text copied to clipboard.'),
                                  ),
                                );
                            }
                          },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  text.isEmpty
                      ? 'No raw text was stored for this paper.'
                      : text,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails() {
    final detail = _detail;
    if (detail == null) return;
    final paper = detail.paper;
    final metadata = paper.metadata;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paper details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (metadata.examName != null)
                _detailRow(dialogContext, 'Exam', metadata.examName!),
              if (metadata.subject != null)
                _detailRow(dialogContext, 'Subject', metadata.subject!),
              if (metadata.examYear != null)
                _detailRow(dialogContext, 'Year', '${metadata.examYear}'),
              if (metadata.className != null)
                _detailRow(dialogContext, 'Class', metadata.className!),
              if (metadata.duration != null)
                _detailRow(dialogContext, 'Duration', metadata.duration!),
              if (metadata.totalMarks != null)
                _detailRow(
                  dialogContext,
                  'Total marks',
                  _formatMarks(metadata.totalMarks!),
                ),
              _detailRow(dialogContext, 'File', paper.fileName),
              _detailRow(dialogContext, 'Extraction', paper.method.label),
              _detailRow(dialogContext, 'Pages', '${paper.pageCount}'),
              _detailRow(
                dialogContext,
                'Imported',
                DateFormat.yMMMd().add_jm().format(paper.createdAt),
              ),
              if (paper.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Extraction warnings',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final warning in paper.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: scheme.tertiary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            warning,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatMarks(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.paper.title ?? 'Paper',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (detail != null) ...[
            IconButton(
              tooltip: 'Paper details',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: _showDetails,
            ),
            IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _export,
            ),
            PopupMenuButton<_PaperAction>(
              tooltip: 'More actions',
              onSelected: (action) {
                switch (action) {
                  case _PaperAction.rename:
                    _rename();
                    break;
                  case _PaperAction.rawText:
                    _showRawText();
                    break;
                  case _PaperAction.delete:
                    _delete();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _PaperAction.rename,
                  child: _MenuRow(
                    icon: Icons.drive_file_rename_outline_rounded,
                    label: 'Rename paper',
                  ),
                ),
                PopupMenuItem(
                  value: _PaperAction.rawText,
                  child: _MenuRow(
                    icon: Icons.article_outlined,
                    label: 'View extracted text',
                  ),
                ),
                PopupMenuItem(
                  value: _PaperAction.delete,
                  child: _MenuRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete paper',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Could not load this paper',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail;
    if (detail == null) {
      return const Center(child: Text('Paper not found.'));
    }

    final visible = _visibleQuestions;

    return Column(
      children: [
        _SummaryCard(paper: detail.paper),
        _FilterBar(
          search: _search,
          filter: _filter,
          visible: visible.length,
          total: detail.questions.length,
          onSearchChanged: () => setState(() {}),
          onFilterChanged: (filter) => setState(() => _filter = filter),
          onClearSearch: () {
            _search.clear();
            setState(() {});
          },
        ),
        Expanded(
          child: QuestionTable(
            questions: visible,
            onTap: _editQuestion,
            emptyMessage: detail.questions.isEmpty
                ? 'No questions were extracted from this paper.'
                : 'No questions match your search or filter.',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.paper});

  final PaperRecord paper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  paper.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${paper.confidencePercent.round()}% confidence',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.list_alt_rounded,
                  label: '${paper.questionCount} questions',
                ),
                if (paper.reviewCount > 0)
                  _StatChip(
                    icon: Icons.rate_review_outlined,
                    label: '${paper.reviewCount} to review',
                  ),
                _StatChip(
                  icon: Icons.pages_outlined,
                  label: '${paper.pageCount} pages',
                ),
                _StatChip(
                  icon: paper.method == ExtractionMethod.ocr
                      ? Icons.document_scanner_outlined
                      : Icons.auto_awesome_rounded,
                  label: paper.method.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.search,
    required this.filter,
    required this.visible,
    required this.total,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onClearSearch,
  });

  final TextEditingController search;
  final _QuestionFilter filter;
  final int visible;
  final int total;
  final VoidCallback onSearchChanged;
  final ValueChanged<_QuestionFilter> onFilterChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: search,
            onChanged: (_) => onSearchChanged(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search questions, options or Q.No',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: onClearSearch,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final option in _QuestionFilter.values)
                      ChoiceChip(
                        label: Text(option.label),
                        selected: filter == option,
                        onSelected: (_) => onFilterChanged(option),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$visible / $total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

