import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'paper_screen.dart';

/// Previous Year Questions (PYQ) Explorer screen.
class PYQExplorerScreen extends StatefulWidget {
  const PYQExplorerScreen({super.key});

  @override
  State<PYQExplorerScreen> createState() => _PYQExplorerScreenState();
}

class _PYQExplorerScreenState extends State<PYQExplorerScreen> {
  List<StoredQuestion> _filteredQuestions = [];
  bool _loading = true;

  String _selectedYear = 'All';
  String _selectedDifficulty = 'All';
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  static const List<String> _years = [
    'All', '2025', '2024', '2023', '2022', '2021', '2020',
  ];
  static const List<String> _difficulties = ['All', 'Easy', 'Medium', 'Hard'];

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
    setState(() => _loading = false);
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredQuestions = [];
    });
  }

  Widget _buildYearFilter(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            'Year:',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: _years.map((y) {
              final selected = _selectedYear == y;
              return ChoiceChip(
                label: Text(y),
                selected: selected,
                onSelected: (_) => setState(() => _selectedYear = y),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyFilter(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            'Difficulty:',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: _difficulties.map((d) {
              final selected = _selectedDifficulty == d;
              return ChoiceChip(
                label: Text(d),
                selected: selected,
                onSelected: (_) => setState(() => _selectedDifficulty = d),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context, ThemeData theme) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search questions...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('PYQ Explorer'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  child: Column(
                    children: [
                      _buildYearFilter(context, theme),
                      const SizedBox(height: 10),
                      _buildDifficultyFilter(context, theme),
                      const SizedBox(height: 10),
                      _buildSearchField(context, theme),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '${_filteredQuestions.length} PYQ question${_filteredQuestions.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: _filteredQuestions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.history_rounded, size: 64, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text(
                                'No PYQ questions found',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Import papers with PYQ questions or mark questions as PYQ from the edit sheet.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredQuestions.length,
                          itemBuilder: (_, i) {
                            final q = _filteredQuestions[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                                  child: Center(child: Text(q.number, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                                ),
                                title: Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (q.examYear != null) _PyqChip(label: '${q.examYear}', icon: Icons.date_range_rounded),
                                        if (q.examName != null && q.examName!.isNotEmpty) _PyqChip(label: q.examName!, icon: Icons.school_rounded),
                                        _PyqChip(label: q.difficulty, icon: Icons.label_rounded),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaperScreen(paperId: q.paperId))),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _PyqChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PyqChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
        label: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
        backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
