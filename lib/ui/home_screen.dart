import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_strings.dart';
import '../data/models.dart';
import '../services/document_reader.dart';
import '../state/app_state.dart';
import 'import_screen.dart';
import 'paper_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';
import 'profile_setup_screen.dart';
import 'syllabus_tracker_screen.dart';
import 'pyq_explorer_screen.dart';
import 'create_mock_test_screen.dart';
import 'analytics_screen.dart';
import 'bookmarks_screen.dart';
import 'revision_queue_screen.dart';
import 'explanations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, List<StoredQuestion>> _categorized = {};
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categorized = await AppScope.read(context)
          .getTopQuestionsByCategory();
      if (!mounted) return;
      setState(() {
        _categorized = categorized;
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  int get _totalTopQuestions =>
      _categorized.values.fold(0, (sum, list) => sum + list.length);

  Future<void> _pickAndImport(BuildContext context, AppState state) async {
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'txt'],
        dialogTitle: 'Choose a PDF or TXT file',
      );
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, 'Could not open the file picker: $error');
      }
      return;
    }

    if (picked == null) return;

    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, 'Could not read the selected file: $error');
      }
      return;
    }

    final file = SelectedFile(
      name: picked.name,
      path: picked.path,
      bytes: bytes,
    );

    if (!file.isSupported) {
      if (context.mounted) {
        _showSnack(context, 'Please choose a PDF or TXT file.');
      }
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImportScreen(file: file)),
    );
    if (mounted) _loadCategories();
  }

  Widget _buildDrawer(BuildContext context, AppState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = AppText.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.tertiary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.fact_check_rounded,
                    color: scheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ExamVault',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  t.tagline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.home_rounded,
            label: t.home,
            selected: true,
            onTap: () => Navigator.of(context).pop(),
          ),
          _DrawerItem(
            icon: Icons.calendar_today_rounded,
            label: t.calendar,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          const Divider(height: 1),
          _DrawerItem(
            icon: Icons.school_rounded,
            label: t.syllabusTracker,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyllabusTrackerScreen()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.history_rounded,
            label: t.pyqExplorer,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PYQExplorerScreen()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.assignment_rounded,
            label: t.mockTests,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateMockTestScreen()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.show_chart_rounded,
            label: t.analytics,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.schedule_rounded,
            label: t.revisionQueue,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RevisionQueueScreen()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.bookmark_rounded,
            label: t.bookmarks,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: t.explanations,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExplanationsScreen()),
              );
            },
          ),
          const Divider(height: 1),
          _DrawerItem(
            icon: Icons.person_rounded,
            label: t.profile,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.info_outline_rounded,
            label: t.aboutHelp,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.fact_check_rounded,
                size: 21,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('ExamVault',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'About & help',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickAndImport(context, state),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Import paper'),
      ),
      drawer: _buildDrawer(context, state),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, AppState state) {
    if (state.loading && state.papers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.loadError != null && state.papers.isEmpty) {
      return _ErrorState(
        message: state.loadError!,
        onRetry: state.refresh,
      );
    }

    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_totalTopQuestions == 0 && state.papers.isEmpty) {
      return _EmptyState(onImport: () => _pickAndImport(context, state));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await state.refresh();
        _loadCategories();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _StatsCard(state: state),
          const SizedBox(height: 20),
          _TopQuestionsHeader(),
          const SizedBox(height: 12),
          ..._homeCategoriesWithIcons.entries.map((entry) {
            final category = entry.key;
            final questions = _categorized[category] ?? const [];
            return _CategoryCard(
              category: category,
              icon: entry.value,
              questions: questions,
              onTapQuestion: (q) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaperScreen(paperId: q.paperId),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          if (state.papers.isNotEmpty) ...[
            _PapersSection(state: state),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  static const Map<String, IconData> _homeCategoriesWithIcons = {
    'History': Icons.event_note_rounded,
    'Geography': Icons.public_rounded,
    'Social Science': Icons.people_rounded,
    'Maths': Icons.calculate_rounded,
  };
}

class _TopQuestionsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      child: Text(
        'Top questions',
        style: theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.icon,
    required this.questions,
    required this.onTapQuestion,
  });

  final String category;
  final IconData icon;
  final List<StoredQuestion> questions;
  final void Function(StoredQuestion) onTapQuestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  category,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (questions.isNotEmpty)
                  Text(
                    '${questions.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          // Questions list
          if (questions.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'No questions yet — import a paper to get started.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ] else
            ...questions.map(
              (q) => _QuestionRow(
                question: q,
                onTap: () => onTapQuestion(q),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.question, required this.onTap});

  final StoredQuestion question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  question.number,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(question),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(StoredQuestion q) {
    final parts = <String>[];
    if (q.section.isNotEmpty) parts.add(q.section);
    if (q.marks != null) parts.add('${q.marks} M');
    return parts.join('  •  ');
  }
}

class _PapersSection extends StatelessWidget {
  const _PapersSection({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Row(
            children: [
              Text(
                'Your papers',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${state.papers.length} total',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        for (final paper in state.papers.take(5)) ...[
          _PaperCard(paper: paper),
          const SizedBox(height: 8),
        ],
        if (state.papers.length > 5)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('View all'),
            ),
          ),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
        size: 22,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: selected ? scheme.primary : scheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: selected
          ? scheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      onTap: onTap,
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your question bank',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                value: '${state.papers.length}',
                label: 'Papers',
              ),
              _Stat(
                value: '${state.totalQuestions}',
                label: 'Questions',
              ),
              _Stat(
                value: '${state.totalNeedsReview}',
                label: 'To review',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimary;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.paper});

  final PaperRecord paper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPdf = paper.sourceType.name == 'pdf';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PaperScreen(paperId: paper.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                  color: scheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniChip(
                          icon: Icons.list_alt_rounded,
                          label: '${paper.questionCount} questions',
                        ),
                        if (paper.reviewCount > 0)
                          _MiniChip(
                            icon: Icons.rate_review_outlined,
                            label: '${paper.reviewCount} to review',
                            highlight: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = highlight
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final fg = highlight ? scheme.onErrorContainer : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner_rounded,
                size: 48,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Turn any paper into a question table',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Import a PDF or TXT file. ExamVault finds every numbered '
              'question, marks, sections and multiple-choice options, then '
              'stores one question per row.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Choose PDF or TXT'),
            ),
            const SizedBox(height: 14),
            Text(
              'Digital PDFs use their text layer. Scanned papers fall back to '
              'on-device OCR automatically.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Could not load your library',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
