import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_strings.dart';
import '../data/models.dart';
import 'paper_screen.dart';

/// Lists every question the user bookmarked.
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

  Future<void> _remove(int questionId) async {
    await AppScope.read(context).toggleBookmark(questionId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final t = AppText.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.bookmarks), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: state.bookmarks.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: [
                        const SizedBox(height: 56),
                        Icon(
                          Icons.bookmark_border_rounded,
                          size: 64,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t.noBookmarksTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.noBookmarksBody,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.bookmarks.length,
                      itemBuilder: (_, index) {
                        final entry = state.bookmarks[index];
                        return _BookmarkCard(
                          entry: entry,
                          t: t,
                          onRemove: () => _remove(entry.bookmark.questionId),
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PaperScreen(paperId: entry.question.paperId),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.entry,
    required this.t,
    required this.onRemove,
    required this.onOpen,
  });

  final BookmarkEntry entry;
  final AppText t;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    entry.question.number,
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _bookmarkDate(t, entry.bookmark.createdAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.removeBookmark,
                icon: Icon(
                  Icons.bookmark_rounded,
                  color: scheme.primary,
                ),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _bookmarkDate(AppText t, DateTime date) {
    final now = DateTime.now();
    final days = now.difference(date).inDays;
    if (days <= 0) return t.bookmarkedToday;
    if (days == 1) return t.bookmarkedYesterday;
    if (days < 7) return t.bookmarkedDaysAgo(days);
    return '${date.day}/${date.month}/${date.year}';
  }
}
