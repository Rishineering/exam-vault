import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_strings.dart';
import '../data/models.dart';
import 'paper_screen.dart';

/// Spaced-repetition queue: questions whose review date has arrived.
class RevisionQueueScreen extends StatefulWidget {
  const RevisionQueueScreen({super.key});

  @override
  State<RevisionQueueScreen> createState() => _RevisionQueueScreenState();
}

class _RevisionQueueScreenState extends State<RevisionQueueScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    await state.loadDueRevisions();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _review(
    int index,
    bool remembered,
  ) async {
    final state = AppScope.read(context);
    final entry = state.dueRevisions[index];
    final item = entry.item;
    final newInterval =
        remembered ? (item.intervalDays * 2).clamp(1, 180) : 1;
    final newEase = remembered
        ? (item.easeFactor + 0.1).clamp(1.3, 3.0)
        : (item.easeFactor - 0.2).clamp(1.3, 3.0);

    await state.updateRevisionSchedule(
      item.copyWith(
        nextReview: DateTime.now().add(Duration(days: newInterval)),
        intervalDays: newInterval,
        easeFactor: newEase,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppText.read(context).revisionUpdated)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final t = AppText.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.revisionQueue), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: state.dueRevisions.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: [
                        const SizedBox(height: 56),
                        Icon(
                          Icons.schedule_rounded,
                          size: 64,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t.noRevisionsTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.noRevisionsBody,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.dueRevisions.length,
                      itemBuilder: (_, index) {
                        final entry = state.dueRevisions[index];
                        return _RevisionCard(
                          entry: entry,
                          t: t,
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PaperScreen(
                                paperId: entry.question.paperId,
                              ),
                            ),
                          ),
                          onReview: (remembered) =>
                              _review(index, remembered),
                        );
                      },
                    ),
            ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    required this.entry,
    required this.t,
    required this.onOpen,
    required this.onReview,
  });

  final RevisionEntry entry;
  final AppText t;
  final VoidCallback onOpen;
  final ValueChanged<bool> onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = entry.item;
    final question = entry.question;
    final overdue = item.nextReview.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: overdue
                          ? scheme.errorContainer
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        question.number,
                        style: TextStyle(
                          color: overdue
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
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
                        const SizedBox(height: 6),
                        Text(
                          '${_dueLabel(item.nextReview, t)} • '
                          '${t.revisionInterval(item.intervalDays)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => onReview(false),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(t.markIncorrect),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => onReview(true),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(t.markCorrect),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dueLabel(DateTime nextReview, AppText t) {
    final now = DateTime.now();
    if (nextReview.isBefore(now)) return t.revisionOverdue;
    final days = nextReview.difference(now).inDays;
    if (days <= 0) return t.revisionDueToday;
    if (days == 1) return t.revisionTomorrow;
    return t.revisionInDays(days);
  }
}
