import '../models.dart';
import '../text/normalize.dart';

/// Result of recognising a question number at the start of a line.
class QuestionStartMatch {
  const QuestionStartMatch({
    required this.number,
    required this.remainder,
    required this.strong,
  });

  final int number;
  final String remainder;

  /// Strong matches use explicit punctuation (`1.`, `1)`, `Q1.`). Weak
  /// matches are bare `1 text` lines and are only accepted when the numbering
  /// continues the sequence.
  final bool strong;
}

// ---------------------------------------------------------------------------
// Question numbering
// ---------------------------------------------------------------------------

final RegExp _qNoPattern = RegExp(
  r'^\s*(?:Q(?:uestion)?|Ques)\s*\.?\s*No\.?\s*[:\-]?\s*(\d{1,3})\s*[\.\)\:]?\s*(.*)$',
  caseSensitive: false,
);

final RegExp _qCompact = RegExp(
  r'^\s*(?:Q(?:uestion|ues)?)\s*[-\.]?\s*(\d{1,3})\s*[\.\)\:]?\s+(.*)$',
  caseSensitive: false,
);

final RegExp _qNumbered = RegExp(
  r'^\s*(?:Q(?:uestion|ues)?\s*\.?\s*)?(\d{1,3})\s*([\.\)\:])(?!\d)\s*(.*)$',
  caseSensitive: false,
);

final RegExp _qParen = RegExp(r'^\s*\(\s*(\d{1,3})\s*\)\s*(.*)$');
final RegExp _qDash = RegExp(r'^\s*(\d{1,3})\s*-\s+(.*)$');
final RegExp _qLoose = RegExp(r'^\s*(\d{1,3})\s+(\S.*)$');

QuestionStartMatch? matchQuestionStart(String rawLine) {
  final line = normalizeInline(rawLine);
  if (line.isEmpty) return null;

  var m = _qNoPattern.firstMatch(line);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n != null) {
      return QuestionStartMatch(
        number: n,
        remainder: (m.group(2) ?? '').trim(),
        strong: true,
      );
    }
  }

  m = _qCompact.firstMatch(line);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n != null) {
      return QuestionStartMatch(
        number: n,
        remainder: (m.group(2) ?? '').trim(),
        strong: true,
      );
    }
  }

  m = _qNumbered.firstMatch(line);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n != null) {
      return QuestionStartMatch(
        number: n,
        remainder: (m.group(3) ?? '').trim(),
        strong: true,
      );
    }
  }

  m = _qParen.firstMatch(line);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n != null) {
      return QuestionStartMatch(
        number: n,
        remainder: (m.group(2) ?? '').trim(),
        strong: false,
      );
    }
  }

  m = _qDash.firstMatch(line);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n != null) {
      return QuestionStartMatch(
        number: n,
        remainder: (m.group(2) ?? '').trim(),
        strong: false,
      );
    }
  }

  m = _qLoose.firstMatch(line);
  if (m != null) {
    final n = int.tryParse(m.group(1)!);
    if (n != null) {
      return QuestionStartMatch(
        number: n,
        remainder: (m.group(2) ?? '').trim(),
        strong: false,
      );
    }
  }

  return null;
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

final RegExp _sectionPattern = RegExp(
  r'^\s*(SECTION|PART|UNIT|BLOCK|GROUP)\s*[-–—:\.]?\s*([A-Za-z]{1,4}|\d{1,2}|[IVXLC]{1,5})\b\s*[:\-–—]?\s*(.*)$',
  caseSensitive: false,
);

/// Returns a canonical section label such as `SECTION A`, or null.
String? matchSectionHeader(String rawLine) {
  final line = normalizeInline(rawLine);
  if (line.isEmpty || line.length > 160) return null;

  final m = _sectionPattern.firstMatch(line);
  if (m == null) return null;

  final label = m.group(2)!;
  final isUpper = label == label.toUpperCase();
  final isNumeric = RegExp(r'^\d+$').hasMatch(label);
  // Reject prose such as "part of the question" where the label is lower-case.
  if (!isUpper && !isNumeric) return null;

  final keyword = m.group(1)!.toUpperCase();
  final rest = (m.group(3) ?? '').trim();
  final cleanRest =
      rest.replaceAll(RegExp(r'^[\-–—:\.\s]+'), '').trim();
  if (cleanRest.isEmpty) return '$keyword ${label.toUpperCase()}';
  if (cleanRest.length <= 60) {
    return '$keyword ${label.toUpperCase()} - $cleanRest';
  }
  return '$keyword ${label.toUpperCase()}';
}

// ---------------------------------------------------------------------------
// Instructions / page furniture
// ---------------------------------------------------------------------------

final RegExp _instructionStart = RegExp(
  r'^\s*(general\s+instructions?|instructions?|note\s*[:\-]|time\s+allowed|maximum\s+marks|max\.?\s*marks|total\s+marks|all\s+questions|attempt\s+all|duration\s*[:\-]|class\s*[:\-]|subject\s*[:\-]|marks\s*[:\-])',
  caseSensitive: false,
);

final RegExp _instructionWords = RegExp(
  r'(all\s+questions|attempt\s+all|candidates?|question\s+paper|this\s+paper|compulsory|internal\s+choice|write\s+(?:the\s+)?answers?|answer\s+all|marks\s+are\s+given|time\s+allowed|maximum\s+marks|general\s+instructions?|each\s+question\s+carries|section\s+[a-z]\s+(?:contains|has))',
  caseSensitive: false,
);

bool isInstructionLine(String rawLine) {
  final line = normalizeInline(rawLine);
  if (line.isEmpty) return false;
  return _instructionStart.hasMatch(line);
}

bool looksLikeInstructionText(String rawLine) {
  final line = normalizeInline(rawLine);
  if (line.isEmpty) return false;
  return _instructionWords.hasMatch(line);
}

final RegExp _pageNumberPattern = RegExp(
  r'^\s*(?:page\s*)?[\[\(]?\s*-?\s*\d{1,3}\s*-?\s*[\]\)]?\s*(?:(?:of|/)\s*\d{1,3})?\s*$',
  caseSensitive: false,
);

final RegExp _pageWordsPattern = RegExp(
  r'^\s*(?:p\.?\s*t\.?\s*o\.?|contd\.?|continued\.?|turn\s+over|please\s+turn\s+over)\s*$',
  caseSensitive: false,
);

bool isPageNumberLine(String rawLine) {
  final line = normalizeInline(rawLine);
  if (line.isEmpty) return false;
  if (_pageWordsPattern.hasMatch(line)) return true;
  return _pageNumberPattern.hasMatch(line) && line.length <= 24;
}

// ---------------------------------------------------------------------------
// Marks
// ---------------------------------------------------------------------------

final List<RegExp> _marksPatterns = [
  RegExp(
    r'[\[\(]\s*(\d{1,3}(?:\.\d+)?)\s*(?:marks?|mks?|mrks?)\s*[\]\)]',
    caseSensitive: false,
  ),
  RegExp(
    r'(\d{1,3}(?:\.\d+)?)\s*(?:marks?|mks?|mrks?)\b',
    caseSensitive: false,
  ),
  RegExp(
    r'\b(?:marks?|mks?|mrks?)\s*[:\-]\s*(\d{1,3}(?:\.\d+)?)',
    caseSensitive: false,
  ),
  RegExp(r'[\[\(]\s*(\d{1,3}(?:\.\d+)?)\s*[\]\)]\s*$'),
  RegExp(r'\[\s*(\d{1,3}(?:\.\d+)?)\s*\]\s*$'),
];

double? extractMarks(String text) {
  for (final pattern in _marksPatterns) {
    final m = pattern.firstMatch(text);
    if (m == null) continue;
    final value = double.tryParse(m.group(1)!);
    if (value != null && value > 0 && value <= 200) return value;
  }
  return null;
}

/// Removes marks annotations from the question text while keeping the value.
String stripMarks(String text) {
  var result = text;
  for (var i = 0; i < 3; i++) {
    result = result.replaceAll(_marksPatterns[i], ' ');
  }
  final trimmed = result.trimRight();
  for (var i = 3; i < _marksPatterns.length; i++) {
    final m = _marksPatterns[i].firstMatch(trimmed);
    if (m != null && trimmed.length > 12) {
      result = trimmed.substring(0, m.start).trimRight();
      break;
    }
  }
  return result
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .trim();
}

// ---------------------------------------------------------------------------
// Multiple-choice options
// ---------------------------------------------------------------------------

final RegExp _mcqCue = RegExp(
  r'(\?|choose\s+the\s+correct|select\s+the\s+correct|which\s+of\s+the\s+following|correct\s+option|fill\s+in\s+the\s+blank|assertion|reason\s*\(r\)|match\s+the\s+following|true\s+or\s+false|tick\s+the\s+correct)',
  caseSensitive: false,
);

bool stemLooksLikeMcq(String text) => _mcqCue.hasMatch(text);

final RegExp _optionLine =
    RegExp(r'^\s*[\(\[]?\s*([A-Da-d]|[1-9])\s*[\)\].:\-]\s+(.+)$');

final RegExp _inlineOption =
    RegExp(r'[\(\[]\s*([A-Da-d]|[1-9])\s*[\)\]]\s*');

final RegExp _numericOptionLine =
    RegExp(r'^\s*[\(\[]?\s*[1-9]\s*[\)\].:\-]\s+.+$');

class OptionExtraction {
  const OptionExtraction({
    required this.options,
    required this.bodyLineCount,
    this.stemOverride,
  });

  final List<ParsedOption> options;

  /// How many of the supplied lines belong to the question stem. Any lines
  /// after this index were consumed as options.
  final int bodyLineCount;

  /// When options were written inline on the same line as the stem, the stem
  /// has already been separated out and must replace the consumed lines.
  final String? stemOverride;
}

OptionExtraction extractOptions(List<String> lines) {
  final trimmed = List<String>.from(lines);
  while (trimmed.isNotEmpty && trimmed.last.trim().isEmpty) {
    trimmed.removeLast();
  }
  if (trimmed.isEmpty) {
    return const OptionExtraction(options: [], bodyLineCount: 0);
  }

  final inline = _tryInlineOptions(trimmed);
  if (inline != null) return inline;

  final run = <ParsedOption>[];
  var index = trimmed.length - 1;
  while (index >= 0) {
    final m = _optionLine.firstMatch(trimmed[index].trim());
    if (m == null) break;
    final text = m.group(2)!.trim();
    if (text.isEmpty) break;
    run.insert(0, ParsedOption(label: m.group(1)!, text: text));
    index--;
  }

  if (run.length >= 2) {
    final stem = trimmed.sublist(0, index + 1).join(' ').trim();
    if (_optionsArePlausible(run, stem)) {
      return OptionExtraction(options: run, bodyLineCount: index + 1);
    }
  }

  return OptionExtraction(options: const [], bodyLineCount: trimmed.length);
}

OptionExtraction? _tryInlineOptions(List<String> lines) {
  final last = lines.last.trim();
  final matches = _inlineOption.allMatches(last).toList();
  if (matches.length < 3) return null;

  final options = <ParsedOption>[];
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].end;
    final end = i + 1 < matches.length ? matches[i + 1].start : last.length;
    final text = last.substring(start, end).trim();
    if (text.isEmpty) continue;
    options.add(ParsedOption(label: matches[i].group(1)!, text: text));
  }
  if (options.length < 3) return null;

  final stemBefore = last.substring(0, matches.first.start).trim();
  final previousStem = lines.take(lines.length - 1).join(' ').trim();
  final stem = '$previousStem $stemBefore'.trim();
  if (!_optionsArePlausible(options, stem)) return null;

  final body = lines.sublist(0, lines.length - 1);
  if (stemBefore.isNotEmpty) body.add(stemBefore);
  return OptionExtraction(
    options: options,
    bodyLineCount: body.length,
    stemOverride: stem,
  );
}

bool _optionsArePlausible(List<ParsedOption> options, String stem) {
  if (options.length < 2) return false;

  final labels = options.map((o) => o.label).toList();
  if (labels.toSet().length != labels.length) return false;

  final averageLength = options
          .map((o) => o.text.length)
          .reduce((a, b) => a + b) /
      options.length;
  if (averageLength > 240) return false;

  final allUpper = labels.every((l) => RegExp(r'^[A-Z]$').hasMatch(l));
  final allLower = labels.every((l) => RegExp(r'^[a-z]$').hasMatch(l));
  final allNumeric = labels.every((l) => RegExp(r'^[1-9]$').hasMatch(l));
  final mcq = stemLooksLikeMcq(stem);

  if (allUpper) return true;

  if (allNumeric) {
    final numbers = labels.map(int.parse).toList();
    var sequential = true;
    for (var i = 1; i < numbers.length; i++) {
      if (numbers[i] != numbers[i - 1] + 1) sequential = false;
    }
    return (options.length >= 3 && sequential) || (mcq && options.length >= 2);
  }

  if (allLower) {
    // Lower-case labels are far more often sub-parts than MCQ options.
    return mcq && options.length >= 3;
  }

  return false;
}

bool looksLikeNumericOption(String line) =>
    _numericOptionLine.hasMatch(normalizeInline(line));
