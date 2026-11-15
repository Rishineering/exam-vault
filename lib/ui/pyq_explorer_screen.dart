import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_strings.dart';
import '../data/models.dart';
import 'paper_screen.dart';

/// Previous-year question explorer with year, difficulty and text filters.
class PYQExplorerScreen extends StatefulWidget {
  const PYQExplorerScreen({super.key});

  @override
  State<PYQExplorerScreen> createState() => _PYQExplorerScreenState();
}

class _PYQExplorerScreenState extends State<PYQExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<StoredQuestion> _allQuestions = const [];
  List<StoredQuestion> _filteredQuestions = const [];
  bool _loading = true;

  String _selectedYear = 'All';
  String _selectedDifficulty = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final questions = await AppScope.read(context).getPyqQuestions();
    if (!mounted) return;
    setState(() {
      _allQuestions = questions;
      _loading = false;
      _applyFilters();
    });
  }

  List<String> get _years {
    final values = <String>{'All'};
    for (final question in _allQuestions) {
      final year = question.examYear;
      if (year != null) values.add('$year');
    }
    final sorted = values.where((y) => y != 'All').toList()
      ..sort((a, b) => b.compareTo(a));
    return ['All', ...sorted];
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredQuestions = _allQuestions.where((question) {
      if (_selectedYear != 'All' &&
          '${question.examYear ?? ''}' != _selectedYear) {
        return false;
      }
      if (_selectedDifficulty != 'All' &&
          question.difficulty.toLowerCase() !=
              _selectedDifficulty.toLowerCase()) {
        return false;
      }
      if (query.isEmpty) return true;
      return question.text.toLowerCase().contains(query) ||
          question.number.toLowerCase().contains(query) ||
          question.section.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildYearFilter(ThemeData theme, AppText t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 8),
          child: Text(
            '${t.year}:',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _years.map((year) {
              final selected = _selectedYear == year;
              return ChoiceChip(
                label: Text(year == 'All' ? t.all : year),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedYear = year;
                    _applyFilters();
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyFilter(ThemeData theme, AppText t) {
    final difficulties = <String>[
      'All',
      ...{for (final q in _allQuestions) q.difficulty}
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 8),
          child: Text(
            '${t.difficulty}:',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: difficulties.map((difficulty) {
              final selected = _selectedDifficulty == difficulty;
              final label =
                  difficulty == 'All' ? t.all : t.difficultyLabel(difficulty);
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedDifficulty = difficulty;
                    _applyFilters();
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(AppText t) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: t.searchQuestionsHint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _applyFilters();
                  });
                },
              ),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
          _applyFilters();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = AppText.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.pyqExplorer), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: Column(
                    children: [
                      _buildYearFilter(theme, t),
                      const SizedBox(height: 6),
                      _buildDifficultyFilter(theme, t),
                      const SizedBox(height: 10),
                      _buildSearchField(t),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.pyqCount(_filteredQuestions.length),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredQuestions.isEmpty
                      ? _EmptyPyq(t: t)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredQuestions.length,
                            itemBuilder: (_, index) {
                              final question = _filteredQuestions[index];
                              return _PyqCard(
                                question: question,
                                t: t,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PaperScreen(
                                      paperId: question.paperId,
                                    ),
                                  ),
                                ),
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

class _EmptyPyq extends StatelessWidget {
  const _EmptyPyq({required this.t});

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
          Icons.history_rounded,
          size: 64,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          t.pyqNoResults,
          textAlign: TextAlign.center,
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          t.pyqNoResultsBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PyqCard extends StatelessWidget {
  const _PyqCard({
    required this.question,
    required this.t,
    required this.onTap,
  });

  final StoredQuestion question;
  final AppText t;
  final VoidCallback onTap;

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
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                    question.number,
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
                      question.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (question.examYear != null)
                          _PyqChip(
                            label: '${question.examYear}',
                            icon: Icons.date_range_rounded,
                          ),
                        if ((question.examName ?? '').isNotEmpty)
                          _PyqChip(
                            label: question.examName!,
                            icon: Icons.school_rounded,
                          ),
                        _PyqChip(
                          label: t.difficultyLabel(question.difficulty),
                          icon: Icons.label_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _PyqChip extends StatelessWidget {
  const _PyqChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(
        label,
        style: theme.textTheme.bodySmall
            ?.copyWith(fontWeight: FontWeight.w600, fontSize: 11),
      ),
      backgroundColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
