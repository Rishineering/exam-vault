/// Text normalisation helpers used before any pattern matching.
///
/// PDFs produced by different tools contain ligatures, soft hyphens, smart
/// quotes, zero-width characters and non-breaking spaces. Normalising these
/// early makes every downstream regex dramatically more reliable.
library;

const Map<String, String> _ligatures = {
  '\uFB00': 'ff',
  '\uFB01': 'fi',
  '\uFB02': 'fl',
  '\uFB03': 'ffi',
  '\uFB04': 'ffl',
  '\uFB05': 'st',
  '\uFB06': 'st',
};

/// Normalises a single visual line while preserving meaningful characters.
String normalizeInline(String input) {
  var s = input;
  // Soft hyphen + zero width / direction marks + BOM.
  s = s.replaceAll('\u00AD', '');
  s = s.replaceAll(RegExp(r'[\u200B-\u200F\u2060\uFEFF]'), '');
  // Non-breaking and thin spaces.
  s = s.replaceAll(RegExp(r'[\u00A0\u2000-\u200A\u202F\u205F\u3000]'), ' ');
  // Typographic ligatures.
  for (final entry in _ligatures.entries) {
    s = s.replaceAll(entry.key, entry.value);
  }
  // Smart quotes.
  s = s.replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u2032]'), "'");
  s = s.replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F\u2033]'), '"');
  // Dash variants. Keep the ASCII hyphen so numeric ranges remain readable.
  s = s.replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'), '-');
  // Collapse horizontal whitespace only; vertical whitespace is handled by the
  // caller because blank lines carry paragraph meaning.
  s = s.replaceAll(RegExp(r'[\t\f\v ]+'), ' ');
  return s.trim();
}

/// Aggressive form used only for comparing lines with each other
/// (header/footer detection, duplicate detection).
String normalizeForCompare(String input) {
  var s = normalizeInline(input).toLowerCase();
  s = s.replaceAll(RegExp(r'\d'), '#');
  s = s.replaceAll(RegExp(r'[^a-z# ]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

String collapseSpaces(String input) =>
    input.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r' *\n *'), '\n').trim();

/// Joins a wrapped line to the previous one, undoing end-of-line hyphenation
/// only when it is safe (next word starts with a lowercase letter).
String joinWrapped(String previous, String next) {
  final p = previous.trimRight();
  final n = next.trim();
  if (p.isEmpty) return n;
  if (n.isEmpty) return p;
  if (p.endsWith('-') && !p.endsWith('--') && RegExp(r'^[a-z]').hasMatch(n)) {
    return '${p.substring(0, p.length - 1)}$n';
  }
  return '$p $n';
}

/// Heuristic for OCR garbage / broken font encodings.
bool looksLikeGarbage(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return true;
  var suspicious = 0;
  for (final rune in trimmed.runes) {
    if (rune == 0xFFFD) {
      suspicious += 3;
    } else if (rune < 32 && rune != 9 && rune != 10) {
      suspicious++;
    }
  }
  final alphanumeric =
      RegExp(r'[A-Za-z0-9]').allMatches(trimmed).length;
  final hasMath = RegExp(r'[=+\-*/^<>]').hasMatch(trimmed);
  final ratio = trimmed.isEmpty ? 0.0 : alphanumeric / trimmed.length;
  if (suspicious > 3) return true;
  if (trimmed.length > 12 && ratio < 0.35 && !hasMath) return true;
  return false;
}

/// Title-cases an ALL-CAPS heading while keeping short acronyms intact.
String smartTitleCase(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  final letters = trimmed.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.isEmpty) return trimmed;
  final upperRatio =
      letters.split('').where((c) => c == c.toUpperCase()).length /
          letters.length;
  if (upperRatio < 0.8) return trimmed;
  const keepUpper = {
    'cbse',
    'icse',
    'isc',
    'ncert',
    'ssc',
    'hsc',
    'iit',
    'jee',
    'neet',
    'upsc',
    'ib',
    'ap',
    'ts',
  };
  return trimmed
      .split(RegExp(r'\s+'))
      .map((word) {
        final lower = word.toLowerCase();
        if (keepUpper.contains(lower.replaceAll(RegExp(r'[^a-z]'), ''))) {
          return word.toUpperCase();
        }
        if (word.length <= 2 && word == word.toUpperCase()) return word;
        return word
            .split('-')
            .map((part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
            .join('-');
      })
      .join(' ');
}
