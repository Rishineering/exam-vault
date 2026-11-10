/// Core data models shared by the extraction pipeline, the parser and the UI.
///
/// These types are deliberately free of Flutter / plugin imports so that the
/// whole extraction engine can be unit-tested with `flutter test` on a desktop
/// VM without an Android device.
library;

enum SourceType { pdf, txt }

enum ExtractionMethod {
  embeddedText('Embedded PDF text'),
  ocr('OCR (scanned PDF)'),
  plainText('Plain text file');

  const ExtractionMethod(this.label);

  final String label;
}

/// One visual line of text on a page, with its bounding box.
///
/// Coordinates are in PDF points (or arbitrary units for plain-text input).
/// `pageNumber` is 1-based.
class LayoutLine {
  const LayoutLine({
    required this.pageNumber,
    required this.text,
    this.left = 0,
    this.top = 0,
    this.width = 0,
    this.height = 0,
  });

  final int pageNumber;
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  LayoutLine copyWith({
    int? pageNumber,
    String? text,
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    return LayoutLine(
      pageNumber: pageNumber ?? this.pageNumber,
      text: text ?? this.text,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  String toString() =>
      'LayoutLine(p$pageNumber, x=$left, y=$top, w=$width, "$text")';
}

class PageLayout {
  const PageLayout({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.lines,
  });

  final int pageNumber;
  final double width;
  final double height;
  final List<LayoutLine> lines;
}

/// A file that has been read from disk and turned into positioned lines.
class RawDocument {
  const RawDocument({
    required this.sourceType,
    required this.method,
    required this.fileName,
    required this.pages,
    required this.rawText,
    this.filePath,
  });

  final SourceType sourceType;
  final ExtractionMethod method;
  final String fileName;
  final String? filePath;
  final List<PageLayout> pages;
  final String rawText;

  int get pageCount => pages.isEmpty ? 1 : pages.length;

  int get characterCount => rawText.replaceAll(RegExp(r'\s'), '').length;

  double get charactersPerPage =>
      pageCount == 0 ? 0 : characterCount / pageCount;
}

class PaperMetadata {
  const PaperMetadata({
    this.title,
    this.subject,
    this.examYear,
    this.totalMarks,
    this.duration,
    this.examName,
    this.className,
  });

  final String? title;
  final String? subject;
  final int? examYear;
  final double? totalMarks;
  final String? duration;
  final String? examName;
  final String? className;

  bool get isEmpty =>
      title == null &&
      subject == null &&
      examYear == null &&
      totalMarks == null &&
      duration == null &&
      examName == null &&
      className == null;

  PaperMetadata copyWith({
    String? title,
    String? subject,
    int? examYear,
    double? totalMarks,
    String? duration,
    String? examName,
    String? className,
  }) {
    return PaperMetadata(
      title: title ?? this.title,
      subject: subject ?? this.subject,
      examYear: examYear ?? this.examYear,
      totalMarks: totalMarks ?? this.totalMarks,
      duration: duration ?? this.duration,
      examName: examName ?? this.examName,
      className: className ?? this.className,
    );
  }
}

class ParsedOption {
  const ParsedOption({required this.label, required this.text});

  final String label;
  final String text;

  Map<String, dynamic> toJson() => {'label': label, 'text': text};

  @override
  String toString() => '($label) $text';
}

/// A single row of the final questions table.
class ParsedQuestion {
  const ParsedQuestion({
    required this.number,
    required this.orderIndex,
    required this.text,
    this.section = '',
    this.marks,
    this.options = const [],
    this.pageNumber = 1,
    this.confidence = 0.5,
    this.warnings = const [],
    this.rawBlock = '',
  });

  final String number;
  final int orderIndex;
  final String text;
  final String section;
  final double? marks;
  final List<ParsedOption> options;
  final int pageNumber;
  final double confidence;
  final List<String> warnings;
  final String rawBlock;

  bool get needsReview => confidence < 0.6 || warnings.isNotEmpty;

  bool get isMultipleChoice => options.length >= 2;

  ParsedQuestion copyWith({
    String? number,
    int? orderIndex,
    String? text,
    String? section,
    double? marks,
    bool clearMarks = false,
    List<ParsedOption>? options,
    int? pageNumber,
    double? confidence,
    List<String>? warnings,
    String? rawBlock,
  }) {
    return ParsedQuestion(
      number: number ?? this.number,
      orderIndex: orderIndex ?? this.orderIndex,
      text: text ?? this.text,
      section: section ?? this.section,
      marks: clearMarks ? null : (marks ?? this.marks),
      options: options ?? this.options,
      pageNumber: pageNumber ?? this.pageNumber,
      confidence: confidence ?? this.confidence,
      warnings: warnings ?? this.warnings,
      rawBlock: rawBlock ?? this.rawBlock,
    );
  }
}

class ParseResult {
  const ParseResult({
    required this.metadata,
    required this.questions,
    required this.warnings,
    required this.averageConfidence,
    required this.pageCount,
    required this.method,
    required this.rawText,
    required this.characterCount,
  });

  final PaperMetadata metadata;
  final List<ParsedQuestion> questions;
  final List<String> warnings;
  final double averageConfidence;
  final int pageCount;
  final ExtractionMethod method;
  final String rawText;
  final int characterCount;

  int get reviewCount => questions.where((q) => q.needsReview).length;
}
