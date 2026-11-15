import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import 'question_edit_sheet.dart';

/// A horizontally scrollable, spreadsheet-style table of extracted questions.
///
/// The header row stays pinned while the question rows scroll vertically, and
/// the whole table scrolls horizontally on narrow phone screens.
class QuestionTable extends StatelessWidget {
  const QuestionTable({
    super.key,
    required this.questions,
    required this.onTap,
    this.emptyMessage = 'No questions match your filter.',
  });

  final List<StoredQuestion> questions;
  final ValueChanged<StoredQuestion> onTap;
  final String emptyMessage;

  static const double _indexWidth = 44;
  static const double _numberWidth = 72;
  static const double _sectionWidth = 130;
  static const double _questionWidth = 340;
  static const double _marksWidth = 64;
  static const double _optionsWidth = 164;
  static const double _pageWidth = 56;
  static const double _confidenceWidth = 70;
  static const double _reviewWidth = 72;
  static const double _actionsWidth = 56;

  static const double _totalWidth = _indexWidth +
      _numberWidth +
      _sectionWidth +
      _questionWidth +
      _marksWidth +
      _optionsWidth +
      _pageWidth +
      _confidenceWidth +
      _reviewWidth +
      _actionsWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_rows_outlined,
                size: 44,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _totalWidth,
        child: Column(
          children: [
            _TableHeader(scheme: scheme),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  return _QuestionRow(
                    index: index,
                    question: questions[index],
                    onTap: () => onTap(questions[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: scheme.onSurfaceVariant,
        );

    Widget cell(String label, double width, {TextAlign align = TextAlign.start}) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(label, style: style, textAlign: align),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          cell('#', QuestionTable._indexWidth, align: TextAlign.center),
          cell('Q.NO', QuestionTable._numberWidth),
          cell('SECTION', QuestionTable._sectionWidth),
          cell('QUESTION', QuestionTable._questionWidth),
          cell('MARKS', QuestionTable._marksWidth, align: TextAlign.center),
          cell('OPTIONS', QuestionTable._optionsWidth),
          cell('PAGE', QuestionTable._pageWidth, align: TextAlign.center),
          cell('CONF.', QuestionTable._confidenceWidth, align: TextAlign.center),
          cell('REVIEW', QuestionTable._reviewWidth, align: TextAlign.center),
          cell('ACTIONS', QuestionTable._actionsWidth, align: TextAlign.center),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.index,
    required this.question,
    required this.onTap,
  });

  final int index;
  final StoredQuestion question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodySmall;

    Widget textCell(
      String text,
      double width, {
      TextStyle? style,
      int maxLines = 6,
      TextAlign align = TextAlign.start,
    }) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Text(
            text,
            style: style ?? bodyStyle,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
          ),
        ),
      );
    }

    final optionsText = question.options
        .map((option) => '${option.label}) ${option.text}')
        .join('   ');

    return Material(
      color: index.isEven
          ? scheme.surface
          : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              textCell(
                '${index + 1}',
                QuestionTable._indexWidth,
                style: bodyStyle?.copyWith(color: scheme.onSurfaceVariant),
                align: TextAlign.center,
                maxLines: 1,
              ),
              textCell(
                question.number,
                QuestionTable._numberWidth,
                style: bodyStyle?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
              ),
              textCell(
                question.section.isEmpty ? '—' : question.section,
                QuestionTable._sectionWidth,
                maxLines: 3,
              ),
              textCell(
                question.text,
                QuestionTable._questionWidth,
                maxLines: 6,
              ),
              textCell(
                question.marks == null ? '—' : _formatMarks(question.marks!),
                QuestionTable._marksWidth,
                align: TextAlign.center,
                maxLines: 1,
              ),
              textCell(
                optionsText.isEmpty ? '—' : optionsText,
                QuestionTable._optionsWidth,
                maxLines: 4,
              ),
              textCell(
                '${question.pageNumber}',
                QuestionTable._pageWidth,
                align: TextAlign.center,
                maxLines: 1,
              ),
              SizedBox(
                width: QuestionTable._confidenceWidth,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: _ConfidenceBadge(value: question.confidence),
                ),
              ),
              SizedBox(
                width: QuestionTable._reviewWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Tooltip(
                    message: question.needsReview
                        ? 'Flagged for review'
                        : 'Reviewed automatically',
                    child: Icon(
                      question.needsReview
                          ? Icons.rate_review_outlined
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: question.needsReview
                          ? scheme.error
                          : scheme.primary,
                    ),
                  ),
                ),
              ),
              // Bookmark + explanation actions
              SizedBox(
                width: QuestionTable._actionsWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Explanation badge
                      FutureBuilder<bool>(
                        future: _hasExplanation(context, question.id),
                        builder: (context, snapshot) {
                          final hasExplanation = snapshot.data ?? false;
                          return Tooltip(
                            message: hasExplanation
                                ? 'Explanation available'
                                : 'Add explanation',
                            child: IconButton(
                              icon: Icon(
                                hasExplanation
                                    ? Icons.chat_bubble_outline_rounded
                                    : Icons.chat_bubble_outlined,
                                size: 16,
                                color: hasExplanation
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                showQuestionEditSheet(context, question);
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      // Bookmark star
                      FutureBuilder<bool>(
                        future: _isBookmarked(context, question.id),
                        builder: (context, snapshot) {
                          final bookmarked = snapshot.data ?? false;
                          return Tooltip(
                            message: bookmarked
                                ? 'Remove bookmark'
                                : 'Bookmark',
                            child: IconButton(
                              icon: Icon(
                                bookmarked
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 16,
                                color: bookmarked
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              onPressed: () => _toggleBookmark(context, question.id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatMarks(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static Future<bool> _hasExplanation(BuildContext context, int questionId) async {
    final state = AppScope.read(context);
    final explanation = await state.getQuestionExplanation(questionId, 'en');
    return explanation != null;
  }

  static Future<bool> _isBookmarked(BuildContext context, int questionId) async {
    final state = AppScope.read(context);
    return await state.isQuestionBookmarked(questionId);
  }

  static Future<void> _toggleBookmark(BuildContext context, int questionId) async {
    final state = AppScope.read(context);
    await state.toggleBookmark(questionId);
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (value * 100).round();

    final Color background;
    final Color foreground;
    if (value >= 0.8) {
      background = scheme.primaryContainer;
      foreground = scheme.onPrimaryContainer;
    } else if (value >= 0.6) {
      background = scheme.tertiaryContainer;
      foreground = scheme.onTertiaryContainer;
    } else {
      background = scheme.errorContainer;
      foreground = scheme.onErrorContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$percent%',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
