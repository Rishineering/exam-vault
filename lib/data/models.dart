import '../core/models.dart';

/// A paper row as stored in SQLite, plus its metadata.
class PaperRecord {
  const PaperRecord({
    required this.id,
    required this.title,
    required this.fileName,
    required this.sourceType,
    required this.method,
    required this.pageCount,
    required this.questionCount,
    required this.reviewCount,
    required this.averageConfidence,
    required this.metadata,
    required this.warnings,
    required this.createdAt,
    this.rawText = '',
  });

  final int id;
  final String title;
  final String fileName;
  final SourceType sourceType;
  final ExtractionMethod method;
  final int pageCount;
  final int questionCount;
  final int reviewCount;
  final double averageConfidence;
  final PaperMetadata metadata;
  final List<String> warnings;
  final DateTime createdAt;
  final String rawText;

  double get confidencePercent => (averageConfidence * 100).roundToDouble();

  PaperRecord copyWith({
    int? id,
    String? title,
    String? fileName,
    SourceType? sourceType,
    ExtractionMethod? method,
    int? pageCount,
    int? questionCount,
    int? reviewCount,
    double? averageConfidence,
    PaperMetadata? metadata,
    List<String>? warnings,
    DateTime? createdAt,
    String? rawText,
  }) {
    return PaperRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      sourceType: sourceType ?? this.sourceType,
      method: method ?? this.method,
      pageCount: pageCount ?? this.pageCount,
      questionCount: questionCount ?? this.questionCount,
      reviewCount: reviewCount ?? this.reviewCount,
      averageConfidence: averageConfidence ?? this.averageConfidence,
      metadata: metadata ?? this.metadata,
      warnings: warnings ?? this.warnings,
      createdAt: createdAt ?? this.createdAt,
      rawText: rawText ?? this.rawText,
    );
  }
}

/// One question row as stored in SQLite.
class StoredQuestion {
  const StoredQuestion({
    required this.id,
    required this.paperId,
    required this.number,
    required this.orderIndex,
    required this.text,
    required this.section,
    required this.options,
    required this.pageNumber,
    required this.category,
    required this.confidence,
    required this.needsReview,
    required this.warnings,
    required this.rawBlock,
    this.marks,
  });

  final int id;
  final int paperId;
  final String number;
  final int orderIndex;
  final String text;
  final String section;
  final double? marks;
  final List<ParsedOption> options;
  final int pageNumber;
  final String category;
  final double confidence;
  final bool needsReview;
  final List<String> warnings;
  final String rawBlock;

  bool get isMultipleChoice => options.length >= 2;

  ParsedQuestion toParsed() => ParsedQuestion(
        number: number,
        orderIndex: orderIndex,
        text: text,
        section: section,
        marks: marks,
        options: options,
        pageNumber: pageNumber,
        confidence: confidence,
        warnings: warnings,
        rawBlock: rawBlock,
      );

  StoredQuestion copyWith({
    String? number,
    int? orderIndex,
    String? text,
    String? section,
    double? marks,
    bool clearMarks = false,
    List<ParsedOption>? options,
    int? pageNumber,
    String? category,
    double? confidence,
    bool? needsReview,
    List<String>? warnings,
    String? rawBlock,
  }) {
    return StoredQuestion(
      id: id,
      paperId: paperId,
      number: number ?? this.number,
      orderIndex: orderIndex ?? this.orderIndex,
      text: text ?? this.text,
      section: section ?? this.section,
      marks: clearMarks ? null : (marks ?? this.marks),
      options: options ?? this.options,
      pageNumber: pageNumber ?? this.pageNumber,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      needsReview: needsReview ?? this.needsReview,
      warnings: warnings ?? this.warnings,
      rawBlock: rawBlock ?? this.rawBlock,
    );
  }
}

class PaperDetail {
  const PaperDetail({required this.paper, required this.questions});

  final PaperRecord paper;
  final List<StoredQuestion> questions;

  int get reviewCount => questions.where((q) => q.needsReview).length;

  PaperDetail copyWith({PaperRecord? paper, List<StoredQuestion>? questions}) {
    return PaperDetail(
      paper: paper ?? this.paper,
      questions: questions ?? this.questions,
    );
  }
}
