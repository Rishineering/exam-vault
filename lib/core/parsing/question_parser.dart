import 'dart:math' as math;

import '../layout/layout_processor.dart';
import '../models.dart';
import '../text/normalize.dart';
import 'metadata_parser.dart';
import 'patterns.dart';

/// Converts a [RawDocument] into a [ParseResult] containing one row per
/// question.
///
/// The parser is intentionally deterministic and rule-based: exam papers follow
/// strong conventions (numbered questions, marks in brackets, section headers)
/// and a transparent rule engine is easier to debug and unit-test than an
/// opaque model.
class QuestionParser {
  const QuestionParser();

  ParseResult parse(RawDocument doc) {
    final ordered = const LayoutProcessor().process(doc);
    final lines = ordered.where((l) => l.text.trim().isNotEmpty).toList();
    final fullText = lines.map((l) => l.text.trim()).join('\n');

    final firstIndex = _findFirstQuestion(lines);
    final preamble = firstIndex > 0
        ? lines.take(firstIndex).map((l) => l.text.trim()).toList()
        : firstIndex < 0
            ? lines.map((l) => l.text.trim()).toList()
            : <String>[];

    final metadata =
        const MetadataParser().parse(preamble: preamble, fullText: fullText);

    final warnings = <String>[];
    var questions = firstIndex < 0
        ? _fallback(lines, warnings)
        : _segment(lines, firstIndex, warnings);

    if (questions.isEmpty && firstIndex >= 0) {
      questions = _fallback(lines, warnings);
    }
    questions = _dedupe(questions);

    if (doc.method == ExtractionMethod.ocr) {
      warnings.add(
          'Text was recovered with OCR. Verify numbers, symbols and equations.');
    }
    if (doc.sourceType == SourceType.pdf && doc.characterCount < 200) {
      warnings.add(
          'Very little text was found. This PDF may be a scanned image; try OCR.');
    }

    final average = questions.isEmpty
        ? 0.0
        : questions.map((q) => q.confidence).reduce((a, b) => a + b) /
            questions.length;

    return ParseResult(
      metadata: metadata,
      questions: questions,
      warnings: warnings,
      averageConfidence: average,
      pageCount: doc.pageCount,
      method: doc.method,
      rawText: fullText,
      characterCount: doc.characterCount,
    );
  }

  // -------------------------------------------------------------------------
  // Finding the first real question
  // -------------------------------------------------------------------------

  int _findFirstQuestion(List<LayoutLine> lines) {
    final limit = math.min(lines.length, 250);
    for (var i = 0; i < limit; i++) {
      final text = lines[i].text.trim();
      if (text.isEmpty) continue;
      if (isInstructionLine(text)) continue;

      final start = matchQuestionStart(text);
      if (start == null) continue;
      if (start.number < 1 || start.number > 50) continue;
      if (!start.strong && start.remainder.length < 8) continue;

      // Numbered instruction bullets ("1. All questions are compulsory.") are
      // extremely common. Skip them, but keep genuine questions that merely
      // mention the words.
      if (start.remainder.isNotEmpty &&
          looksLikeInstructionText(start.remainder) &&
          !start.remainder.contains('?')) {
        continue;
      }

      return i;
    }
    return -1;
  }

  // -------------------------------------------------------------------------
  // Segmentation
  // -------------------------------------------------------------------------

  List<ParsedQuestion> _segment(
    List<LayoutLine> lines,
    int firstIndex,
    List<String> warnings,
  ) {
    final questions = <ParsedQuestion>[];
    final lastBySection = <String, int>{};
    var section = '';

    // A section header often appears immediately before the first question and
    // is therefore part of the preamble. Pick it up so questions are labelled
    // correctly.
    for (var i = 0; i < firstIndex; i++) {
      final header = matchSectionHeader(lines[i].text.trim());
      if (header != null) section = header;
    }

    var newSection = true;
    _Pending? current;
    var accepted = 0;

    void flush() {
      final pending = current;
      if (pending == null) return;
      final question = _finalize(pending, questions.length);
      if (question != null) questions.add(question);
      current = null;
    }

    for (var i = firstIndex; i < lines.length; i++) {
      final line = lines[i];
      final text = line.text.trim();
      if (text.isEmpty) {
        final active = current;
        if (active != null) active.body.add('');
        continue;
      }

      // A lone year (often a running header that survived) is never a question.
      if (RegExp(r'^(?:19|20)\d{2}\.?$').hasMatch(text)) continue;

      final sectionHeader = matchSectionHeader(text);
      if (sectionHeader != null) {
        flush();
        section = sectionHeader;
        newSection = true;
        continue;
      }

      final start = matchQuestionStart(text);

      // "1) ... 2) ..." inside a multiple-choice question are options, not new
      // questions. Decide before the normal numbering check.
      final active = current;
      if (start != null && active != null && _isNumericOption(start, active)) {
        active.body.add(text);
        active.raw.add(text);
        continue;
      }

      if (start != null) {
        final last = lastBySection[section] ?? 0;
        if (_acceptStart(
          start: start,
          last: last,
          newSection: newSection,
          accepted: accepted,
        )) {
          flush();
          final previous = newSection ? 0 : last;
          final pending = _Pending(
            number: start.number.toString(),
            section: section,
            page: line.pageNumber,
            strong: start.strong,
            previous: previous,
          );

          if (start.number == 1 && !newSection && last > 1) {
            pending.warnings.add('Question numbering restarted at 1');
          }
          if (start.remainder.isNotEmpty) pending.body.add(start.remainder);
          pending.raw.add(text);

          current = pending;
          lastBySection[section] = start.number;
          newSection = false;
          accepted++;
          continue;
        }
      }

      final target = current;
      if (target == null) continue;

      // Rejected numbered lines (years, list items, equations) stay in the
      // current question.
      target.body.add(text);
      target.raw.add(text);
    }

    flush();

    if (questions.isNotEmpty) {
      final restarted = questions
          .where((q) => q.warnings.any((w) => w.contains('restarted')))
          .length;
      if (restarted > 0) {
        warnings.add(
            'Question numbering restarted $restarted time(s). Sections may be missing headers.');
      }
    }

    return questions;
  }

  bool _acceptStart({
    required QuestionStartMatch start,
    required int last,
    required bool newSection,
    required int accepted,
  }) {
    final n = start.number;
    if (n < 1 || n > 300) return false;
    if (accepted == 0) return n <= 50;
    if (newSection) return n >= 1 && n <= 200;
    if (n == last + 1) return true;
    if (n > last && n <= last + 3) return true;
    if (n == 1 && last > 1) return start.strong;
    return false;
  }

  bool _isNumericOption(QuestionStartMatch start, _Pending current) {
    final n = start.number;
    if (n < 1 || n > 4) return false;

    final stem = current.body.join(' ').trim();
    if (stem.isEmpty || !stemLooksLikeMcq(stem)) return false;

    final numericCount =
        current.body.where((line) => looksLikeNumericOption(line)).length;
    final remainder = start.remainder.trim();

    if (numericCount == 0) {
      final currentNumber = int.tryParse(current.number) ?? -1;
      // If it continues the question numbering it is a real question.
      return n != currentNumber + 1 && remainder.length < 120;
    }
    if (numericCount >= 4) return false;
    return remainder.length < 90;
  }

  // -------------------------------------------------------------------------
  // Finalising one question
  // -------------------------------------------------------------------------

  ParsedQuestion? _finalize(_Pending pending, int orderIndex) {
    final body = List<String>.from(pending.body);
    while (body.isNotEmpty && body.first.trim().isEmpty) {
      body.removeAt(0);
    }
    while (body.isNotEmpty && body.last.trim().isEmpty) {
      body.removeLast();
    }

    if (body.isEmpty) {
      return ParsedQuestion(
        number: pending.number,
        orderIndex: orderIndex,
        text: '',
        section: pending.section,
        pageNumber: pending.page,
        confidence: 0.15,
        warnings: ['Question has no text', ...pending.warnings],
        rawBlock: pending.raw.join('\n'),
      );
    }

    final optionResult = extractOptions(body);
    final stemLines = body.take(optionResult.bodyLineCount).toList();
    final stemRaw = optionResult.stemOverride ?? stemLines.join('\n');
    final fullRaw = body.join('\n');

    final marks = extractMarks(stemRaw) ?? extractMarks(fullRaw);
    var text = optionResult.stemOverride != null
        ? optionResult.stemOverride!
        : _assemble(stemLines);
    text = stripMarks(text);
    text = _tidy(text);

    final warnings = <String>[...pending.warnings];
    if (text.isEmpty && optionResult.options.isNotEmpty) {
      text = 'Choose the correct option.';
      warnings.add('Question stem was empty; inferred from the options');
    }
    if (text.isNotEmpty && text.length < 10) {
      warnings.add('Very short question text');
    }
    if (text.isEmpty) {
      warnings.add('Question text is empty');
    }

    final parsedNumber = int.tryParse(pending.number);
    final sequential =
        pending.previous > 0 && parsedNumber == pending.previous + 1;

    final confidence = _confidence(
      strong: pending.strong,
      sequential: sequential,
      text: text,
      marks: marks,
      options: optionResult.options,
      warnings: warnings,
    );

    return ParsedQuestion(
      number: pending.number,
      orderIndex: orderIndex,
      text: text,
      section: pending.section,
      marks: marks,
      options: optionResult.options,
      pageNumber: pending.page,
      confidence: confidence,
      warnings: warnings,
      rawBlock: fullRaw,
    );
  }

  String _assemble(List<String> lines) {
    var result = '';
    for (final rawLine in lines) {
      final raw = normalizeInline(rawLine);
      if (raw.isEmpty) {
        if (result.isNotEmpty && !result.endsWith('\n')) result += '\n';
        continue;
      }
      if (result.isEmpty) {
        result = raw;
        continue;
      }

      final startsSubpart =
          RegExp(r'^[\(\[]\s*(?:[a-z]|[ivx]+|\d+)\s*[\)\]]').hasMatch(raw);

      if (startsSubpart) {
        result = '${result.trimRight()}\n$raw';
      } else if (result.endsWith('-') && RegExp(r'^[a-z]').hasMatch(raw)) {
        result = '${result.substring(0, result.length - 1)}$raw';
      } else {
        result = '$result $raw';
      }
    }
    return result;
  }

  String _tidy(String text) {
    var s = text;
    s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    s = s.replaceAll(RegExp(r' *\n *'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    s = s.replaceAll(RegExp(r'^[\s\-:;,]+'), '');
    s = s.replaceAll(RegExp(r'^\.\s+'), '');
    return s.trim();
  }

  double _confidence({
    required bool strong,
    required bool sequential,
    required String text,
    required double? marks,
    required List<ParsedOption> options,
    required List<String> warnings,
  }) {
    var score = 0.40;
    if (strong) score += 0.18;
    if (sequential) score += 0.10;
    if (marks != null) score += 0.10;
    if (text.length >= 20) score += 0.10;
    if (text.length >= 60) score += 0.05;
    if (options.length >= 2) score += 0.05;
    if (text.length < 8) score -= 0.25;
    if (text.isEmpty) score -= 0.35;
    if (looksLikeGarbage(text)) score -= 0.20;
    if (warnings.any((w) => w.contains('restarted'))) score -= 0.05;
    return score.clamp(0.05, 0.99).toDouble();
  }

  // -------------------------------------------------------------------------
  // De-duplication
  // -------------------------------------------------------------------------

  List<ParsedQuestion> _dedupe(List<ParsedQuestion> input) {
    final seen = <String>{};
    final output = <ParsedQuestion>[];
    for (final question in input) {
      final key =
          '${question.section}|${question.number}|${normalizeForCompare(question.text)}';
      if (!seen.add(key)) continue;
      output.add(question.copyWith(orderIndex: output.length));
    }
    return output;
  }

  // -------------------------------------------------------------------------
  // Fallback for papers with no usable numbering
  // -------------------------------------------------------------------------

  List<ParsedQuestion> _fallback(List<LayoutLine> lines, List<String> warnings) {
    var blocks = <List<LayoutLine>>[];
    var current = <LayoutLine>[];
    var length = 0;

    void flush() {
      if (current.isEmpty) return;
      blocks.add(current);
      current = <LayoutLine>[];
      length = 0;
    }

    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) {
        flush();
        continue;
      }
      if (matchSectionHeader(text) != null) {
        flush();
        continue;
      }
      if (current.isEmpty && isInstructionLine(text)) continue;

      current.add(line);
      length += text.length;

      final endsSentence = RegExp(r'[\?\!\.]$').hasMatch(text);
      if ((endsSentence && length > 60) || length > 450) flush();
    }
    flush();

    if (blocks.length <= 1 && lines.length > 12) {
      final chunked = <List<LayoutLine>>[];
      for (var i = 0; i < lines.length; i += 3) {
        chunked.add(lines.sublist(i, math.min(i + 3, lines.length)));
      }
      blocks = chunked;
    }

    final output = <ParsedQuestion>[];
    for (final block in blocks) {
      final text = _tidy(block.map((l) => l.text.trim()).join(' '));
      if (text.isEmpty) continue;
      output.add(ParsedQuestion(
        number: '${output.length + 1}',
        orderIndex: output.length,
        text: text,
        pageNumber: block.first.pageNumber,
        confidence: 0.30,
        warnings: const [
          'No question numbers detected; text split into paragraphs'
        ],
        rawBlock: block.map((l) => l.text.trim()).join('\n'),
      ));
    }

    if (output.isNotEmpty) {
      warnings.add(
          'No reliable question numbering was found. The text was split into paragraph rows; please review.');
    } else {
      warnings.add('No questions could be detected in this file.');
    }
    return output;
  }
}

class _Pending {
  _Pending({
    required this.number,
    required this.section,
    required this.page,
    required this.strong,
    required this.previous,
  });

  final String number;
  final String section;
  final int page;
  final bool strong;
  final int previous;

  final List<String> body = [];
  final List<String> raw = [];
  final List<String> warnings = [];
}
