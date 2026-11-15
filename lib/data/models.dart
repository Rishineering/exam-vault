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
    required this.difficulty,
    required this.importance,
    this.correctOption,
    required this.isPyq,
    this.examYear,
    this.examName,
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
  final String difficulty;
  final String importance;
  final String? correctOption;
  final bool isPyq;
  final int? examYear;
  final String? examName;
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
    String? difficulty,
    String? importance,
    String? correctOption,
    bool clearCorrectOption = false,
    bool? isPyq,
    int? examYear,
    String? examName,
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
      difficulty: difficulty ?? this.difficulty,
      importance: importance ?? this.importance,
      correctOption:
          clearCorrectOption ? null : (correctOption ?? this.correctOption),
      isPyq: isPyq ?? this.isPyq,
      examYear: examYear ?? this.examYear,
      examName: examName ?? this.examName,
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

/// An LLM-generated question stored in the `generated_questions` table.
class GeneratedQuestion {
  const GeneratedQuestion({
    required this.id,
    required this.number,
    required this.text,
    required this.section,
    this.marks,
    required this.category,
    required this.confidence,
    required this.needsReview,
    required this.pageNumber,
    required this.options,
    this.correctOption,
    required this.sourceCategory,
    required this.generationBatch,
    required this.createdAt,
    this.rawBlock = '',
  });

  final int id;
  final String number;
  final String text;
  final String section;
  final double? marks;
  final String category;
  final double confidence;
  final bool needsReview;
  final int pageNumber;
  final List<ParsedOption> options;
  final String? correctOption;
  final String sourceCategory;
  final String generationBatch;
  final DateTime createdAt;
  final String rawBlock;

  GeneratedQuestion copyWith({
    int? id,
    String? number,
    String? text,
    String? section,
    double? marks,
    bool clearMarks = false,
    String? category,
    double? confidence,
    bool? needsReview,
    int? pageNumber,
    List<ParsedOption>? options,
    String? correctOption,
    bool clearCorrectOption = false,
    String? sourceCategory,
    String? generationBatch,
    DateTime? createdAt,
    String? rawBlock,
  }) {
    return GeneratedQuestion(
      id: id ?? this.id,
      number: number ?? this.number,
      text: text ?? this.text,
      section: section ?? this.section,
      marks: clearMarks ? null : (marks ?? this.marks),
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      needsReview: needsReview ?? this.needsReview,
      pageNumber: pageNumber ?? this.pageNumber,
      options: options ?? this.options,
      correctOption:
          clearCorrectOption ? null : (correctOption ?? this.correctOption),
      sourceCategory: sourceCategory ?? this.sourceCategory,
      generationBatch: generationBatch ?? this.generationBatch,
      createdAt: createdAt ?? this.createdAt,
      rawBlock: rawBlock ?? this.rawBlock,
    );
  }
}

/// User's exam profile set during signup/login.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.targetExam,
    this.targetDate,
    required this.language,
    required this.profileSetup,
    required this.createdAt,
  });

  final int id;
  final String targetExam;
  final String? targetDate;
  final String language;
  final bool profileSetup;
  final DateTime createdAt;

  UserProfile copyWith({
    int? id,
    String? targetExam,
    String? targetDate,
    String? language,
    bool? profileSetup,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      targetExam: targetExam ?? this.targetExam,
      targetDate: targetDate ?? this.targetDate,
      language: language ?? this.language,
      profileSetup: profileSetup ?? this.profileSetup,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// User-defined/customizable subject for syllabus tracking.
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.color,
    required this.weight,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String color;
  final double weight;
  final bool isActive;
  final DateTime createdAt;

  Subject copyWith({
    int? id,
    String? name,
    String? color,
    double? weight,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A syllabus topic under a subject.
class SyllabusTopic {
  const SyllabusTopic({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.isCompleted,
    required this.totalQuestions,
    required this.coveredQuestions,
  });

  final int id;
  final int subjectId;
  final String name;
  final bool isCompleted;
  final int totalQuestions;
  final int coveredQuestions;

  double get completionPercent =>
      totalQuestions == 0 ? 0.0 : (coveredQuestions / totalQuestions) * 100;

  SyllabusTopic copyWith({
    int? id,
    int? subjectId,
    String? name,
    bool? isCompleted,
    int? totalQuestions,
    int? coveredQuestions,
  }) {
    return SyllabusTopic(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      isCompleted: isCompleted ?? this.isCompleted,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      coveredQuestions: coveredQuestions ?? this.coveredQuestions,
    );
  }
}

/// Mock test metadata.
class MockTest {
  const MockTest({
    required this.id,
    required this.title,
    required this.examProfile,
    this.subjectFilter,
    this.topicFilter,
    this.difficultyFilter,
    required this.questionCount,
    required this.durationMinutes,
    required this.isPyqOnly,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String examProfile;
  final String? subjectFilter;
  final String? topicFilter;
  final String? difficultyFilter;
  final int questionCount;
  final int durationMinutes;
  final bool isPyqOnly;
  final DateTime createdAt;

  MockTest copyWith({
    int? id,
    String? title,
    String? examProfile,
    String? subjectFilter,
    String? topicFilter,
    String? difficultyFilter,
    int? questionCount,
    int? durationMinutes,
    bool? isPyqOnly,
    DateTime? createdAt,
  }) {
    return MockTest(
      id: id ?? this.id,
      title: title ?? this.title,
      examProfile: examProfile ?? this.examProfile,
      subjectFilter: subjectFilter ?? this.subjectFilter,
      topicFilter: topicFilter ?? this.topicFilter,
      difficultyFilter: difficultyFilter ?? this.difficultyFilter,
      questionCount: questionCount ?? this.questionCount,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isPyqOnly: isPyqOnly ?? this.isPyqOnly,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A user's attempt at a mock test.
class MockTestAttempt {
  const MockTestAttempt({
    required this.id,
    required this.testId,
    required this.score,
    required this.total,
    required this.percentage,
    required this.timeTaken,
    required this.startedAt,
    this.completedAt,
  });

  final int id;
  final int testId;
  final int score;
  final int total;
  final double percentage;
  final int timeTaken;
  final DateTime startedAt;
  final DateTime? completedAt;

  MockTestAttempt copyWith({
    int? id,
    int? testId,
    int? score,
    int? total,
    double? percentage,
    int? timeTaken,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return MockTestAttempt(
      id: id ?? this.id,
      testId: testId ?? this.testId,
      score: score ?? this.score,
      total: total ?? this.total,
      percentage: percentage ?? this.percentage,
      timeTaken: timeTaken ?? this.timeTaken,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// A user's answer to a single question in an attempt.
class AttemptAnswer {
  const AttemptAnswer({
    required this.id,
    required this.attemptId,
    required this.questionId,
    this.userAnswer,
    required this.isCorrect,
    required this.timeSpent,
  });

  final int id;
  final int attemptId;
  final int questionId;
  final String? userAnswer;
  final bool isCorrect;
  final int timeSpent;

  AttemptAnswer copyWith({
    int? id,
    int? attemptId,
    int? questionId,
    String? userAnswer,
    bool? isCorrect,
    int? timeSpent,
  }) {
    return AttemptAnswer(
      id: id ?? this.id,
      attemptId: attemptId ?? this.attemptId,
      questionId: questionId ?? this.questionId,
      userAnswer: userAnswer ?? this.userAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
      timeSpent: timeSpent ?? this.timeSpent,
    );
  }
}

/// Explanation for a question in a specific language.
class QuestionExplanation {
  const QuestionExplanation({
    required this.id,
    required this.questionId,
    required this.language,
    required this.explanation,
    this.source,
  });

  final int id;
  final int questionId;
  final String language;
  final String explanation;
  final String? source;

  QuestionExplanation copyWith({
    int? id,
    int? questionId,
    String? language,
    String? explanation,
    String? source,
  }) {
    return QuestionExplanation(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      language: language ?? this.language,
      explanation: explanation ?? this.explanation,
      source: source ?? this.source,
    );
  }
}

/// A bookmarked question.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.questionId,
    required this.createdAt,
  });

  final int id;
  final int questionId;
  final DateTime createdAt;

  Bookmark copyWith({
    int? id,
    int? questionId,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Spaced repetition revision item.
class RevisionItem {
  const RevisionItem({
    required this.id,
    required this.questionId,
    required this.nextReview,
    required this.intervalDays,
    required this.easeFactor,
  });

  final int id;
  final int questionId;
  final DateTime nextReview;
  final int intervalDays;
  final double easeFactor;

  RevisionItem copyWith({
    int? id,
    int? questionId,
    DateTime? nextReview,
    int? intervalDays,
    double? easeFactor,
  }) {
    return RevisionItem(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      nextReview: nextReview ?? this.nextReview,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
    );
  }
}

/// A compact question record used by screens that join a helper table
/// (explanations, bookmarks, revisions) with the `questions` table.
class QuestionRef {
  const QuestionRef({
    required this.id,
    required this.paperId,
    required this.number,
    required this.text,
    required this.section,
    required this.options,
    required this.difficulty,
    required this.importance,
    required this.isPyq,
    this.examYear,
    this.examName,
    this.marks,
  });

  final int id;
  final int paperId;
  final String number;
  final String text;
  final String section;
  final List<ParsedOption> options;
  final String difficulty;
  final String importance;
  final bool isPyq;
  final int? examYear;
  final String? examName;
  final double? marks;
}

/// An explanation together with the question it belongs to.
class ExplanationEntry {
  const ExplanationEntry({
    required this.explanation,
    required this.question,
  });

  final QuestionExplanation explanation;
  final QuestionRef question;
}

/// A bookmark together with the question it points at.
class BookmarkEntry {
  const BookmarkEntry({required this.bookmark, required this.question});

  final Bookmark bookmark;
  final QuestionRef question;
}

/// A revision item together with the question it points at.
class RevisionEntry {
  const RevisionEntry({required this.item, required this.question});

  final RevisionItem item;
  final QuestionRef question;
}

