import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models.dart';
import '../data/models.dart';

/// Opens a bottom sheet that lets the user correct one extracted question.
///
/// Returns the edited question, or `null` if the user cancels.
Future<StoredQuestion?> showQuestionEditSheet(
  BuildContext context,
  StoredQuestion question,
) {
  return showModalBottomSheet<StoredQuestion>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => QuestionEditSheet(question: question),
  );
}

class QuestionEditSheet extends StatefulWidget {
  const QuestionEditSheet({super.key, required this.question});

  final StoredQuestion question;

  @override
  State<QuestionEditSheet> createState() => _QuestionEditSheetState();
}

class _QuestionEditSheetState extends State<QuestionEditSheet> {
  late final TextEditingController _number;
  late final TextEditingController _section;
  late final TextEditingController _text;
  late final TextEditingController _marks;
  late final TextEditingController _options;

  String? _error;

  @override
  void initState() {
    super.initState();
    final question = widget.question;
    _number = TextEditingController(text: question.number);
    _section = TextEditingController(text: question.section);
    _text = TextEditingController(text: question.text);
    _marks = TextEditingController(
      text: question.marks == null ? '' : _formatMarks(question.marks!),
    );
    _options = TextEditingController(
      text: question.options
          .map((option) => '${option.label}) ${option.text}')
          .join('\n'),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _section.dispose();
    _text.dispose();
    _marks.dispose();
    _options.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'The question text cannot be empty.');
      return;
    }

    final number = _number.text.trim();
    final marksText = _marks.text.trim().replaceAll(',', '.');
    final double? marks = marksText.isEmpty ? null : double.tryParse(marksText);
    if (marksText.isNotEmpty && marks == null) {
      setState(() => _error = 'Marks must be a number, for example 2 or 2.5.');
      return;
    }

    final updated = widget.question.copyWith(
      number: number.isEmpty ? widget.question.number : number,
      section: _section.text.trim(),
      text: text,
      marks: marks,
      clearMarks: marks == null,
      options: _parseOptions(_options.text),
      // A manual correction resolves the review flag.
      warnings: const [],
      needsReview: false,
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final question = widget.question;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note_rounded,
                      color: scheme.primary, size: 26),
                  const SizedBox(width: 8),
                  Text(
                    'Edit question',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Question number',
                        hintText: 'e.g. 14 or 14(a)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _marks,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,]'),
                        ),
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Marks',
                        hintText: 'optional',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _section,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  hintText: 'optional, e.g. Section B',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Question text',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _options,
                minLines: 2,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Options (one per line)',
                  alignLabelWithHint: true,
                  helperText: 'Example: A) Delhi — labels are optional.',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ],
              if (question.warnings.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 16, color: scheme.onTertiaryContainer),
                          const SizedBox(width: 6),
                          Text(
                            'Why this row was flagged',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onTertiaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final warning in question.warnings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '•  $warning',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (question.rawBlock.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined, size: 20),
                    title: Text(
                      'Show original extracted text',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          question.rawBlock,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatMarks(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  /// Parses lines such as `A) Delhi`, `(b) Mumbai`, `3. Chennai` or a bare
  /// `Delhi`. Bare lines are labelled A, B, C… in order.
  static List<ParsedOption> _parseOptions(String raw) {
    final options = <ParsedOption>[];
    final pattern = RegExp(r'^\(?([A-Za-z0-9]{1,2})[).:\-]\s+(.+)$');

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = pattern.firstMatch(trimmed);
      if (match != null) {
        final label = match.group(1)!.toUpperCase();
        final text = match.group(2)!.trim();
        if (text.isNotEmpty) {
          options.add(ParsedOption(label: label, text: text));
          continue;
        }
      }

      final label = String.fromCharCode(65 + (options.length % 26));
      options.add(ParsedOption(label: label, text: trimmed));
    }

    return options;
  }
}
