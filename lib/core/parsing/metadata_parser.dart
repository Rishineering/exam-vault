import '../models.dart';
import '../text/normalize.dart';
import 'patterns.dart';

/// Extracts paper-level metadata from the text that appears before the first
/// question (the "preamble").
class MetadataParser {
  const MetadataParser();

  PaperMetadata parse({
    required List<String> preamble,
    required String fullText,
  }) {
    final cleaned = preamble
        .map(normalizeInline)
        .where((l) => l.isNotEmpty && !isPageNumberLine(l))
        .toList();
    final text = cleaned.join('\n');

    final title = _extractTitle(cleaned);
    final subject = _extractSubject(text, title);
    final year = _extractYear(text);
    final totalMarks = _extractTotalMarks(text);
    final duration = _extractDuration(text);
    final examName = _extractExamName(cleaned);
    final className = _extractClass(text);

    return PaperMetadata(
      title: title,
      subject: subject,
      examYear: year,
      totalMarks: totalMarks,
      duration: duration,
      examName: examName,
      className: className,
    );
  }

  // -------------------------------------------------------------------------

  String? _extractTitle(List<String> lines) {
    if (lines.isEmpty) return null;

    String? questionPaper;
    String? examination;
    String? firstMeaningful;

    for (final raw in lines) {
      final line = normalizeInline(raw);
      if (line.length < 4 || line.length > 180) continue;
      if (isInstructionLine(line)) continue;
      if (isPageNumberLine(line)) continue;
      if (matchSectionHeader(line) != null) continue;
      if (RegExp(r'^\s*(?:time|date|day|subject|class|max|marks|roll|set|code)\b',
              caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }

      firstMeaningful ??= line;

      final lower = line.toLowerCase();
      if (lower.contains('question paper') ||
          lower.contains('question-paper') ||
          lower.contains('sample paper')) {
        questionPaper ??= line;
      } else if (lower.contains('examination') ||
          lower.contains('board') ||
          lower.contains('university') ||
          lower.contains('council')) {
        examination ??= line;
      }
    }

    final chosen = questionPaper ?? examination ?? firstMeaningful;
    if (chosen == null) return null;
    return _cleanTitle(chosen);
  }

  String _cleanTitle(String line) {
    var title = line;
    title = title.replaceAll(
        RegExp(r'\s*(?:time\s*(?:allowed)?|maximum\s*marks|max\.?\s*marks)\s*[:\-].*$',
            caseSensitive: false),
        '');
    title = title.replaceAll(RegExp(r'^[\s\-–—:\.]+'), '');
    title = title.replaceAll(RegExp(r'[\s\-–—:\.]+$'), '');
    title = collapseSpaces(title);
    if (title.length > 140) title = title.substring(0, 140).trim();
    return smartTitleCase(title);
  }

  // -------------------------------------------------------------------------

  static const Map<String, String> _subjectKeywords = {
    'social science': 'Social Science',
    'political science': 'Political Science',
    'environmental studies': 'Environmental Studies',
    'business studies': 'Business Studies',
    'computer science': 'Computer Science',
    'information technology': 'Information Technology',
    'general knowledge': 'General Knowledge',
    'accountancy': 'Accountancy',
    'mathematics': 'Mathematics',
    'statistics': 'Statistics',
    'geography': 'Geography',
    'economics': 'Economics',
    'chemistry': 'Chemistry',
    'reasoning': 'Reasoning',
    'aptitude': 'Aptitude',
    'sanskrit': 'Sanskrit',
    'biology': 'Biology',
    'physics': 'Physics',
    'history': 'History',
    'english': 'English',
    'science': 'Science',
    'hindi': 'Hindi',
    'urdu': 'Urdu',
    'maths': 'Mathematics',
    'math': 'Mathematics',
    'accounts': 'Accountancy',
  };

  String? _extractSubject(String text, String? title) {
    final explicit = RegExp(
      r'subject\s*[:\-]\s*([A-Za-z][A-Za-z &\.\-]{1,40})',
      caseSensitive: false,
    ).firstMatch(text);
    if (explicit != null) {
      final value = collapseSpaces(explicit.group(1)!);
      final canonical = _canonicalSubject(value);
      if (canonical != null) return canonical;
      if (value.length >= 2) return smartTitleCase(value);
    }

    final haystacks = <String>[
      ?title,
      text,
    ];

    final keys = _subjectKeywords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final haystack in haystacks) {
      final lower = haystack.toLowerCase();
      for (final key in keys) {
        final pattern = RegExp(
          '\\b${RegExp.escape(key)}\\b',
          caseSensitive: false,
        );
        if (pattern.hasMatch(lower)) return _subjectKeywords[key];
      }
    }
    return null;
  }

  String? _canonicalSubject(String value) {
    final lower = value.toLowerCase();
    final keys = _subjectKeywords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (RegExp('\\b${RegExp.escape(key)}\\b').hasMatch(lower)) {
        return _subjectKeywords[key];
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------

  int? _extractYear(String text) {
    final matches = RegExp(r'\b(19[5-9]\d|20[0-4]\d)\b')
        .allMatches(text)
        .map((m) => int.parse(m.group(1)!))
        .where((year) => year <= DateTime.now().year + 1)
        .toList();
    if (matches.isEmpty) return null;
    matches.sort();
    return matches.last;
  }

  double? _extractTotalMarks(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'(?:maximum|max\.?|total)\s*marks?\s*[:\-]?\s*(\d{1,4})',
        caseSensitive: false,
      ),
      RegExp(r'\bmarks?\s*[:\-]\s*(\d{1,4})', caseSensitive: false),
      RegExp(r'(\d{1,4})\s*marks?\b', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final m = pattern.firstMatch(text);
      if (m == null) continue;
      final value = double.tryParse(m.group(1)!);
      if (value != null && value > 0 && value <= 1000) return value;
    }
    return null;
  }

  String? _extractDuration(String text) {
    final m = RegExp(
      r'time\s*(?:allowed)?\s*[:\-]?\s*(\d{1,3})\s*(hours?|hrs?|h|minutes?|mins?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (m != null) {
      final amount = int.parse(m.group(1)!);
      final unit = m.group(2)!.toLowerCase();
      if (unit.startsWith('h')) {
        return amount == 1 ? '1 hour' : '$amount hours';
      }
      return amount == 1 ? '1 minute' : '$amount minutes';
    }

    final combo = RegExp(
      r'(\d{1,3})\s*(?:hours?|hrs?)\s*(?:(\d{1,2})\s*(?:minutes?|mins?))?',
      caseSensitive: false,
    ).firstMatch(text);
    if (combo != null) {
      final hours = int.parse(combo.group(1)!);
      final minutes =
          combo.group(2) == null ? 0 : int.parse(combo.group(2)!);
      final hourText = hours == 1 ? '1 hour' : '$hours hours';
      if (minutes == 0) return hourText;
      final minuteText = minutes == 1 ? '1 minute' : '$minutes minutes';
      return '$hourText $minuteText';
    }
    return null;
  }

  // -------------------------------------------------------------------------

  String? _extractExamName(List<String> lines) {
    String? board;
    String? university;
    String? council;
    String? examination;

    for (final raw in lines) {
      final line = normalizeInline(raw);
      if (line.length < 5 || line.length > 180) continue;
      final lower = line.toLowerCase();
      if (lower.contains('question paper') || lower.contains('sample paper')) {
        continue;
      }
      if (lower.contains('board')) {
        board ??= line;
      } else if (lower.contains('university')) {
        university ??= line;
      } else if (lower.contains('council')) {
        council ??= line;
      } else if (lower.contains('examination') ||
          lower.contains('examination,')) {
        examination ??= line;
      }
    }

    final chosen = board ?? university ?? council ?? examination;
    if (chosen == null) return null;
    return _cleanTitle(chosen);
  }

  String? _extractClass(String text) {
    final m = RegExp(
      r'\b(?:class|std\.?|standard)\s*[:\-]?\s*([IVXLC]{1,5}|\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;
    final label = m.group(1)!.toUpperCase();
    return 'Class $label';
  }
}
