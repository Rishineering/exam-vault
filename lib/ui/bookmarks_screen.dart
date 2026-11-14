import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'paper_screen.dart';

/// Bookmarks / Favorites screen — lists all bookmarked questions.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    await state.loadBookmarks();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _toggleBookmark(int questionId) async {
    final state = AppScope.read(context);
    await state.toggleBookmark(questionId);
    setState(() {});
  }

  Future<bool> _isBookmarked(int questionId) async {
    final state = AppScope.read(context);
    return await state.isQuestionBookmarked(questionId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.read(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: state.bookmarks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_border_rounded,
                              size: 64, color: scheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            'No bookmarks yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the star icon on any question to bookmark it.',
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
                      itemCount: state.bookmarks.length,
                      itemBuilder: (_, i) {
                        final bookmark = state.bookmarks[i];
                        return _BookmarkRow(
                          bookmark: bookmark,
                          onToggle: _toggleBookmark,
                          isBookmarked: _isBookmarked,
                        );
                      },
                    ),
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  final Bookmark bookmark;
  final Future<void> Function(int) onToggle;
  final Future<bool> Function(int) isBookmarked;

  const _BookmarkRow({
    required this.bookmark,
    required this.onToggle,
    required this.isBookmarked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FutureBuilder<bool>(
      future: isBookmarked(bookmark.questionId),
      builder: (context, snapshot) {
        final bookmarked = snapshot.data ?? false;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: IconButton(
              icon: Icon(
                bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: bookmarked ? scheme.primary : scheme.onSurfaceVariant,
              ),
              onPressed: () => onToggle(bookmark.questionId),
            ),
            title: const Text(
              'Bookmarked question',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Bookmarked ${_formatDate(bookmark.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              // Open the question's paper — we need the paperId, but Bookmark
              // only stores questionId. For now, show a snack.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Open question from its paper screen.'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
