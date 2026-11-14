import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'paper_screen.dart';

/// Revision Queue screen — spaced repetition.
///
/// Shows questions that are due for review based on the spaced repetition
/// schedule. After answering, the interval is adjusted (easy = longer interval,
/// hard = shorter interval).
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.read(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revision Queue'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: state.dueRevisions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 64, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            'No revisions due',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Questions due for spaced repetition will appear here.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.dueRevisions.length,
                      itemBuilder: (_, i) {
                        final item = state.dueRevisions[i];
                        return _RevisionItemRow(
                          item: item,
                          onReviewed: (wasCorrect) async {
                            // Update interval using simple SM-2-like logic
                            final newInterval = wasCorrect
                                ? (item.intervalDays * 2).clamp(1, 30)
                                : 1;
                            final newEase = wasCorrect
                                ? (item.easeFactor + 0.1).clamp(1.3, 3.0)
                                : (item.easeFactor - 0.2).clamp(1.3, 3.0);
                            final nextReview = DateTime.now()
                                .add(Duration(days: newInterval));

                            await state.updateRevisionSchedule(
                              item.copyWith(
                                nextReview: nextReview,
                                intervalDays: newInterval,
                                easeFactor: newEase,
                              ),
                            );
                            setState(() {});
                          },
                        );
                      },
                    ),
      ),
    );
  }
}

class _RevisionItemRow extends StatelessWidget {
  final RevisionItem item;
  final Future<void> Function(bool) onReviewed;

  const _RevisionItemRow({
    required this.item,
    required this.onReviewed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final isOverdue = item.nextReview.isBefore(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isOverdue ? scheme.errorContainer : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              'Q',
              style: TextStyle(
                color: isOverdue ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: const Text(
          'Question due for revision',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Due ${_formatRelative(item.nextReview)} • '
              'Interval: ${item.intervalDays} day${item.intervalDays == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
              tooltip: 'Mark correct (easy)',
              onPressed: () => onReviewed(true),
            ),
            IconButton(
              icon: const Icon(Icons.error_rounded, color: Colors.red),
              tooltip: 'Mark incorrect (hard)',
              onPressed: () => onReviewed(false),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelative(DateTime date) {
    final now = DateTime.now();
    if (date.isBefore(now)) return 'Overdue';
    final diff = date.difference(now).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }
}
