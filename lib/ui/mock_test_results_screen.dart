import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_strings.dart';
import '../core/models.dart';
import '../data/models.dart';
import 'question_edit_sheet.dart';

enum _ReviewFilter { all, incorrect, correct }

/// Mock test results screen with detailed question-by-question review,
/// answer-key comparisons, and explanation viewer.
class MockTestResultsScreen extends StatefulWidget {
  final int testId;
  final int attemptId;
  final int score;
  final int total;
  final int timeTaken;

  const MockTestResultsScreen({
    super.key,
    required this.testId,
    required this.attemptId,
    required this.score,
    required this.total,
    required this.timeTaken,
  });

  @override
  State<MockTestResultsScreen> createState() => _MockTestResultsScreenState();
}

class _MockTestResultsScreenState extends State<MockTestResultsScreen> {
  late double _percentage;
  List<AttemptAnswerReview> _reviews = const [];
  bool _loadingReviews = true;
  _ReviewFilter _filter = _ReviewFilter.all;

  @override
  void initState() {
    super.initState();
    _percentage = widget.total == 0 ? 0.0 : (widget.score / widget.total) * 100;
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final state = AppScope.read(context);
    final lang = AppText.read(context).language == 'hi' ? 'hi' : 'en';
    final items = await state.getAttemptReviews(
      widget.attemptId,
      language: lang,
    );
    if (!mounted) return;
    setState(() {
      _reviews = items;
      _loadingReviews = false;
    });
  }

  List<AttemptAnswerReview> get _filteredReviews {
    switch (_filter) {
      case _ReviewFilter.incorrect:
        return _reviews.where((r) => !r.answer.isCorrect).toList();
      case _ReviewFilter.correct:
        return _reviews.where((r) => r.answer.isCorrect).toList();
      case _ReviewFilter.all:
        return _reviews;
    }
  }

  Future<void> _toggleBookmark(int questionId) async {
    final state = AppScope.read(context);
    await state.toggleBookmark(questionId);
    setState(() {});
  }

  Future<void> _addToRevision(int questionId) async {
    final state = AppScope.read(context);
    await state.addToRevision(questionId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppText.read(context).addedToRevision)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = AppText.of(context);
    final reviews = _filteredReviews;

    final incorrectCount = widget.total - widget.score;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.testResults),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Percentage Circle
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _percentage >= 60
                        ? Colors.green
                        : scheme.error,
                    _percentage >= 60
                        ? Colors.green.withValues(alpha: 0.7)
                        : scheme.error.withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${_percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.testCompleted,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.scoreSummary(widget.score, widget.total),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Metrics Cards
            Row(
              children: [
                Expanded(
                  child: _ResultCard(
                    title: t.correct,
                    value: widget.score.toString(),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultCard(
                    title: t.wrong,
                    value: '$incorrectCount',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ResultCard(
                    title: t.timeTaken,
                    value: _formatTime(widget.timeTaken, t),
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultCard(
                    title: t.accuracy,
                    value: '${_percentage.toStringAsFixed(0)}%',
                    color: _percentage >= 60 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Question-by-Question Review Section
            Row(
              children: [
                Icon(
                  Icons.playlist_add_check_circle_rounded,
                  size: 22,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.questionReview,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filters (All / Incorrect / Correct)
            Row(
              children: [
                ChoiceChip(
                  label: Text('${t.filterAll} (${_reviews.length})'),
                  selected: _filter == _ReviewFilter.all,
                  onSelected: (_) => setState(() => _filter = _ReviewFilter.all),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('${t.filterIncorrect} ($incorrectCount)'),
                  selected: _filter == _ReviewFilter.incorrect,
                  selectedColor: scheme.errorContainer,
                  onSelected: (_) =>
                      setState(() => _filter = _ReviewFilter.incorrect),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('${t.filterCorrect} (${widget.score})'),
                  selected: _filter == _ReviewFilter.correct,
                  selectedColor: Colors.green.withValues(alpha: 0.2),
                  onSelected: (_) =>
                      setState(() => _filter = _ReviewFilter.correct),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reviews List
            if (_loadingReviews)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (reviews.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.isHindi
                      ? 'इस फ़िल्टर में कोई प्रश्न नहीं है।'
                      : 'No questions match this filter.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (int i = 0; i < reviews.length; i++) ...[
                _ReviewItemCard(
                  review: reviews[i],
                  index: i + 1,
                  t: t,
                  onBookmark: () => _toggleBookmark(reviews[i].question.id),
                  onAddToRevision: () =>
                      _addToRevision(reviews[i].question.id),
                  onEditExplanation: () async {
                    await showQuestionEditSheet(
                      context,
                      reviews[i].question,
                    );
                    _loadReviews();
                  },
                ),
                const SizedBox(height: 12),
              ],

            const SizedBox(height: 24),

            // Back to Home Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.home_rounded),
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.isFirst,
                ),
                label: Text(
                  t.backToHome,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static String _formatTime(int seconds, AppText t) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}${t.minutesShort} ${s}s';
    return '${s}s';
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _ResultCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  final AttemptAnswerReview review;
  final int index;
  final AppText t;
  final VoidCallback onBookmark;
  final VoidCallback onAddToRevision;
  final VoidCallback onEditExplanation;

  const _ReviewItemCard({
    required this.review,
    required this.index,
    required this.t,
    required this.onBookmark,
    required this.onAddToRevision,
    required this.onEditExplanation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final q = review.question;
    final ans = review.answer;
    final isCorrect = ans.isCorrect;
    final userAns = ans.userAnswer?.trim().toUpperCase();
    final correctOpt = q.correctOption?.trim().toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.withValues(alpha: 0.15)
                        : scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 16,
                        color: isCorrect ? Colors.green : scheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCorrect ? t.correct : t.wrong,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isCorrect ? Colors.green : scheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${t.questionLabel} ${q.number}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (ans.timeSpent > 0)
                  Text(
                    '${ans.timeSpent}s',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Question text
            Text(
              q.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Options list
            if (q.options.isNotEmpty) ...[
              for (final opt in q.options) ...[
                _OptionTile(
                  option: opt,
                  isUserAnswer: userAns == opt.label.toUpperCase(),
                  isCorrectAnswer: correctOpt == opt.label.toUpperCase(),
                ),
                const SizedBox(height: 6),
              ],
            ] else ...[
              // Subjective or direct answer
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${t.yourAnswer}: ${userAns ?? t.notAnswered}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Explanation Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.solutionExplanation,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: onEditExplanation,
                        child: Text(
                          t.edit,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.explanation?.explanation.isNotEmpty == true
                        ? review.explanation!.explanation
                        : (t.isHindi
                            ? 'इस प्रश्न के लिए कोई व्याख्या नहीं जोड़ी गई है। संपादन पर टैप करें।'
                            : 'No explanation added for this question yet. Tap Edit to add one.'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: review.explanation?.explanation.isNotEmpty == true
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontStyle:
                          review.explanation?.explanation.isNotEmpty == true
                              ? FontStyle.normal
                              : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Quick actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onAddToRevision,
                  icon: const Icon(Icons.schedule_rounded, size: 16),
                  label: Text(t.revisionQueue),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: t.bookmark,
                  icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                  onPressed: onBookmark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final ParsedOption option;
  final bool isUserAnswer;
  final bool isCorrectAnswer;

  const _OptionTile({
    required this.option,
    required this.isUserAnswer,
    required this.isCorrectAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Color? backgroundColor;
    Color? borderColor;
    Color textColor = scheme.onSurface;
    IconData? icon;
    Color? iconColor;

    if (isCorrectAnswer) {
      backgroundColor = Colors.green.withValues(alpha: 0.12);
      borderColor = Colors.green;
      icon = Icons.check_circle_rounded;
      iconColor = Colors.green;
    } else if (isUserAnswer && !isCorrectAnswer) {
      backgroundColor = scheme.errorContainer.withValues(alpha: 0.4);
      borderColor = scheme.error;
      icon = Icons.cancel_rounded;
      iconColor = scheme.error;
    } else {
      backgroundColor = scheme.surfaceContainerHighest.withValues(alpha: 0.3);
      borderColor = Colors.transparent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isCorrectAnswer
                ? Colors.green
                : isUserAnswer
                    ? scheme.error
                    : scheme.outlineVariant,
            child: Text(
              option.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: (isCorrectAnswer || isUserAnswer)
                    ? Colors.white
                    : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              option.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: (isCorrectAnswer || isUserAnswer)
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: iconColor),
          ],
        ],
      ),
    );
  }
}
