import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/models.dart';
import 'app_database.dart';
import 'dummy_data.dart';
import 'models.dart';

/// CRUD for papers and their questions.
class PaperRepository {
  PaperRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Persists a parsed paper and all of its question rows atomically.
  Future<int> insertParsedPaper({
    required ParseResult result,
    required String fileName,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final title = _fallbackTitle(result.metadata.title, fileName);

    return db.transaction<int>((txn) async {
      final paperId = await txn.insert('papers', {
        'title': title,
        'file_name': fileName,
        'source_type': result.method == ExtractionMethod.plainText
            ? SourceType.txt.name
            : SourceType.pdf.name,
        'extraction_method': result.method.name,
        'page_count': result.pageCount,
        'question_count': result.questions.length,
        'review_count': result.reviewCount,
        'average_confidence': result.averageConfidence,
        'exam_year': result.metadata.examYear,
        'subject': result.metadata.subject,
        'class_name': result.metadata.className,
        'duration': result.metadata.duration,
        'total_marks': result.metadata.totalMarks,
        'exam_name': result.metadata.examName,
        'warnings': jsonEncode(result.warnings),
        'raw_text': result.rawText,
        'created_at': now,
      });

      final batch = txn.batch();
      for (final question in result.questions) {
        batch.insert('questions', {
          'paper_id': paperId,
          'number': question.number,
          'order_index': question.orderIndex,
          'section': question.section,
          'text': question.text,
          'marks': question.marks,
          'options': jsonEncode(question.options.map((o) => o.toJson()).toList()),
          'page_number': question.pageNumber,
          'confidence': question.confidence,
          'needs_review': question.needsReview ? 1 : 0,
          'warnings': jsonEncode(question.warnings),
          'raw_block': question.rawBlock,
        });
      }
      await batch.commit(noResult: true);
      return paperId;
    });
  }

  Future<void> updateQuestion(StoredQuestion question) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.update(
        'questions',
        {
          'number': question.number,
          'section': question.section,
          'text': question.text,
          'marks': question.marks,
          'options': jsonEncode(question.options.map((o) => o.toJson()).toList()),
          'warnings': jsonEncode(question.warnings),
          // A manual edit means the user has reviewed this row.
          'needs_review': 0,
        },
        where: 'id = ?',
        whereArgs: [question.id],
      );
      await _refreshReviewCount(txn, question.paperId);
    });
  }

  Future<void> renamePaper(int paperId, String title) async {
    final db = await _database.database;
    await db.update(
      'papers',
      {'title': title.trim().isEmpty ? 'Untitled paper' : title.trim()},
      where: 'id = ?',
      whereArgs: [paperId],
    );
  }

  Future<void> deletePaper(int paperId) async {
    final db = await _database.database;
    await db.delete('papers', where: 'id = ?', whereArgs: [paperId]);
  }

  Future<void> _refreshReviewCount(DatabaseExecutor txn, int paperId) async {
    final rows = await txn.rawQuery(
      'SELECT COUNT(*) AS c FROM questions WHERE paper_id = ? AND needs_review = 1',
      [paperId],
    );
    final count = Sqflite.firstIntValue(rows) ?? 0;
    await txn.update(
      'papers',
      {'review_count': count},
      where: 'id = ?',
      whereArgs: [paperId],
    );
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  Future<List<PaperRecord>> listPapers() async {
    final db = await _database.database;
    final rows = await db.query(
      'papers',
      columns: [
        'id',
        'title',
        'file_name',
        'source_type',
        'extraction_method',
        'page_count',
        'question_count',
        'review_count',
        'average_confidence',
        'exam_year',
        'subject',
        'class_name',
        'duration',
        'total_marks',
        'exam_name',
        'warnings',
        'created_at',
      ],
      orderBy: 'created_at DESC',
    );
    return rows.map(_paperFromRow).toList();
  }

  Future<PaperRecord?> getPaper(int paperId) async {
    final db = await _database.database;
    final rows = await db.query(
      'papers',
      where: 'id = ?',
      whereArgs: [paperId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _paperFromRow(rows.first);
  }

  Future<List<StoredQuestion>> getQuestions(int paperId) async {
    final db = await _database.database;
    final rows = await db.query(
      'questions',
      where: 'paper_id = ?',
      whereArgs: [paperId],
      orderBy: 'order_index ASC, id ASC',
    );
    return rows.map(_questionFromRow).toList();
  }

  /// Returns up to [limit] questions belonging to [category], ordered by
  /// their position in the paper.
  Future<List<StoredQuestion>> getQuestionsByCategory(
    String category, {
    int? limit,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'questions',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'order_index ASC, id ASC',
      limit: limit,
    );
    return rows.map(_questionFromRow).toList();
  }

  /// Returns every distinct category currently used by stored questions.
  Future<List<String>> getCategories() async {
    final db = await _database.database;
    final rows = await db.query(
      'questions',
      columns: ['category'],
      distinct: true,
      where: "category IS NOT NULL AND category != ''",
    );
    return rows.map((r) => (r['category'] as String?) ?? '').toList();
  }

  // ---------------------------------------------------------------------------
  // App settings (key/value)
  // ---------------------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final db = await _database.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _database.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Seeds the database with dummy questions if no papers exist yet.
  ///
  /// This makes the home screen "Top questions" categories visible on first
  /// launch so the user can immediately see the categorized layout.
  Future<void> seedIfEmpty() async {
    final existing = await listPapers();
    if (existing.isNotEmpty) return;

    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return db.transaction<void>((txn) async {
      final paperId = await txn.insert('papers', {
        'title': DummyData.paperTitle,
        'file_name': 'sample_questions.txt',
        'source_type': SourceType.txt.name,
        'extraction_method': ExtractionMethod.plainText.name,
        'page_count': 1,
        'question_count': DummyData.questions.length,
        'review_count': 0,
        'average_confidence': 0.9,
        'exam_year': DummyData.paperExamYear,
        'subject': DummyData.paperSubject,
        'class_name': DummyData.paperClassName,
        'duration': DummyData.paperDuration,
        'total_marks': DummyData.paperTotalMarks,
        'exam_name': DummyData.paperExamName,
        'warnings': '[]',
        'raw_text': '',
        'created_at': now,
      });

      final batch = txn.batch();
      for (final raw in DummyData.questions) {
        final q = dummyQuestionFromMap(raw);
        batch.insert('questions', {
          'paper_id': paperId,
          'number': q.number,
          'order_index': q.orderIndex,
          'text': q.text,
          'section': q.section,
          'marks': q.marks,
          'options': jsonEncode(
            q.options.map((o) => o.toJson()).toList(),
          ),
          'page_number': q.pageNumber,
          'category': raw['category'] as String,
          'confidence': q.confidence,
          'needs_review': q.needsReview ? 1 : 0,
          'warnings': jsonEncode(q.warnings),
          'raw_block': '',
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<PaperDetail?> getPaperDetail(int paperId) async {
    final paper = await getPaper(paperId);
    if (paper == null) return null;
    final questions = await getQuestions(paperId);
    return PaperDetail(paper: paper, questions: questions);
  }

  // ---------------------------------------------------------------------------
  // Row mapping
  // ---------------------------------------------------------------------------

  PaperRecord _paperFromRow(Map<String, Object?> row) {
    return PaperRecord(
      id: row['id'] as int,
      title: (row['title'] as String?) ?? 'Untitled paper',
      fileName: (row['file_name'] as String?) ?? '',
      sourceType: _sourceType(row['source_type'] as String?),
      method: _method(row['extraction_method'] as String?),
      pageCount: (row['page_count'] as int?) ?? 0,
      questionCount: (row['question_count'] as int?) ?? 0,
      reviewCount: (row['review_count'] as int?) ?? 0,
      averageConfidence:
          ((row['average_confidence'] as num?) ?? 0).toDouble(),
      metadata: PaperMetadata(
        title: row['title'] as String?,
        subject: row['subject'] as String?,
        examYear: row['exam_year'] as int?,
        totalMarks: (row['total_marks'] as num?)?.toDouble(),
        duration: row['duration'] as String?,
        examName: row['exam_name'] as String?,
        className: row['class_name'] as String?,
      ),
      warnings: _decodeStringList(row['warnings'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
      rawText: (row['raw_text'] as String?) ?? '',
    );
  }

  StoredQuestion _questionFromRow(Map<String, Object?> row) {
    return StoredQuestion(
      id: row['id'] as int,
      paperId: row['paper_id'] as int,
      number: (row['number'] as String?) ?? '',
      orderIndex: (row['order_index'] as int?) ?? 0,
      section: (row['section'] as String?) ?? '',
      text: (row['text'] as String?) ?? '',
      marks: (row['marks'] as num?)?.toDouble(),
      options: _decodeOptions(row['options'] as String?),
      pageNumber: (row['page_number'] as int?) ?? 1,
      category: (row['category'] as String?) ?? '',
      confidence: ((row['confidence'] as num?) ?? 0).toDouble(),
      needsReview: ((row['needs_review'] as int?) ?? 0) == 1,
      warnings: _decodeStringList(row['warnings'] as String?),
      rawBlock: (row['raw_block'] as String?) ?? '',
    );
  }

  SourceType _sourceType(String? value) =>
      value == SourceType.txt.name ? SourceType.txt : SourceType.pdf;

  ExtractionMethod _method(String? value) {
    for (final method in ExtractionMethod.values) {
      if (method.name == value) return method;
    }
    return ExtractionMethod.embeddedText;
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } on FormatException {
      // Ignore corrupt JSON and fall back to an empty list.
    }
    return const [];
  }

  List<ParsedOption> _decodeOptions(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => ParsedOption(
                  label: (item['label'] ?? '').toString(),
                  text: (item['text'] ?? '').toString(),
                ))
            .where((option) => option.label.isNotEmpty)
            .toList();
      }
    } on FormatException {
      // Ignore corrupt JSON and fall back to no options.
    }
    return const [];
  }

  String _fallbackTitle(String? metadataTitle, String fileName) {
    final fromMetadata = metadataTitle?.trim();
    if (fromMetadata != null && fromMetadata.isNotEmpty) return fromMetadata;
    final base = p.basenameWithoutExtension(fileName).trim();
    if (base.isEmpty) return 'Untitled paper';
    return base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }
}
