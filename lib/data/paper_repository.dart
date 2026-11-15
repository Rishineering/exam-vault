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

  /// Exposes the underlying database for cross-table operations used by
  /// services such as question generation.
  Future<Database> get database async => _database.database;

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
          'category': '',
          'difficulty': 'Medium',
          'importance': 'Medium',
          'is_pyq': 0,
          'exam_year': null,
          'exam_name': null,
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
          'correct_option': question.correctOption,
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

  /// Returns every stored question, ordered by paper and position.
  Future<List<StoredQuestion>> listAllQuestions() async {
    final db = await _database.database;
    final rows = await db.query(
      'questions',
      orderBy: 'paper_id ASC, order_index ASC, id ASC',
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
          'correct_option': raw['correctOption'] as String?,
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
      difficulty: (row['difficulty'] as String?) ?? 'Medium',
      importance: (row['importance'] as String?) ?? 'Medium',
      correctOption: row['correct_option'] as String?,
      isPyq: ((row['is_pyq'] as int?) ?? 0) == 1,
      examYear: (row['exam_year'] as int?),
      examName: (row['exam_name'] as String?),
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

  // ---------------------------------------------------------------------------
  // Generated questions (LLM pipeline output)
  // ---------------------------------------------------------------------------

  /// Inserts a single generated question and returns its new row id.
  Future<int> insertGeneratedQuestion(GeneratedQuestion question) async {
    final db = await _database.database;
    return await db.insert('generated_questions', {
      'number': question.number,
      'text': question.text,
      'section': question.section,
      'marks': question.marks,
      'category': question.category,
      'confidence': question.confidence,
      'needs_review': question.needsReview ? 1 : 0,
      'page_number': question.pageNumber,
      'options_json': jsonEncode(
        question.options.map((o) => o.toJson()).toList(),
      ),
      'raw_block': question.rawBlock,
      'source_category': question.sourceCategory,
      'generation_batch': question.generationBatch,
      'created_at': question.createdAt.millisecondsSinceEpoch,
    });
  }

  /// Returns generated questions, optionally filtered by batch and/or category.
  Future<List<GeneratedQuestion>> listGeneratedQuestions({
    String? generationBatch,
    String? category,
    int? limit,
  }) async {
    final db = await _database.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (generationBatch != null) {
      whereClauses.add('generation_batch = ?');
      whereArgs.add(generationBatch);
    }
    if (category != null) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    final rows = await db.query(
      'generated_questions',
      columns: [
        'id',
        'number',
        'text',
        'section',
        'marks',
        'category',
        'confidence',
        'needs_review',
        'page_number',
        'options_json',
        'raw_block',
        'source_category',
        'generation_batch',
        'created_at',
      ],
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC, id ASC',
      limit: limit,
    );
    return rows.map(_generatedQuestionFromRow).toList();
  }

  /// Returns the count of generated questions, optionally filtered.
  Future<int> countGeneratedQuestions({
    String? generationBatch,
    String? category,
  }) async {
    final db = await _database.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (generationBatch != null) {
      whereClauses.add('generation_batch = ?');
      whereArgs.add(generationBatch);
    }
    if (category != null) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    final rows = await db.query(
      'generated_questions',
      columns: ['COUNT(*) AS c'],
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Returns every distinct generation batch id, newest first.
  Future<List<String>> getGeneratedQuestionBatches() async {
    final db = await _database.database;
    final rows = await db.query(
      'generated_questions',
      columns: ['generation_batch'],
      distinct: true,
      orderBy: 'generation_batch DESC',
    );
    return rows.map((r) => (r['generation_batch'] as String?) ?? '').toList();
  }

  GeneratedQuestion _generatedQuestionFromRow(Map<String, Object?> row) {
    return GeneratedQuestion(
      id: row['id'] as int,
      number: (row['number'] as String?) ?? '',
      text: (row['text'] as String?) ?? '',
      section: (row['section'] as String?) ?? '',
      marks: (row['marks'] as num?)?.toDouble(),
      category: (row['category'] as String?) ?? '',
      confidence: ((row['confidence'] as num?) ?? 0).toDouble(),
      needsReview: ((row['needs_review'] as int?) ?? 0) == 1,
      pageNumber: (row['page_number'] as int?) ?? 1,
      options: _decodeOptions(row['options_json'] as String?),
      sourceCategory: (row['source_category'] as String?) ?? '',
      generationBatch: (row['generation_batch'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
      rawBlock: (row['raw_block'] as String?) ?? '',
    );
  }

  // ---------------------------------------------------------------------------
  // User Profile CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertUserProfile(UserProfile profile) async {
    final db = await _database.database;
    return await db.insert('user_profiles', {
      'target_exam': profile.targetExam,
      'target_date': profile.targetDate,
      'language': profile.language,
      'profile_setup': profile.profileSetup ? 1 : 0,
      'created_at': profile.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<UserProfile?> getUserProfile() async {
    final db = await _database.database;
    final rows = await db.query(
      'user_profiles',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _userProfileFromRow(rows.first);
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    final db = await _database.database;
    await db.update(
      'user_profiles',
      {
        'target_exam': profile.targetExam,
        'target_date': profile.targetDate,
        'language': profile.language,
        'profile_setup': profile.profileSetup ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  UserProfile _userProfileFromRow(Map<String, Object?> row) {
    return UserProfile(
      id: row['id'] as int,
      targetExam: (row['target_exam'] as String?) ?? '',
      targetDate: (row['target_date'] as String?),
      language: (row['language'] as String?) ?? 'en',
      profileSetup: ((row['profile_setup'] as int?) ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Subject CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertSubject(Subject subject) async {
    final db = await _database.database;
    return await db.insert('subjects', {
      'name': subject.name,
      'color': subject.color,
      'weight': subject.weight,
      'is_active': subject.isActive ? 1 : 0,
      'created_at': subject.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<List<Subject>> listSubjects({bool? isActive}) async {
    final db = await _database.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];
    if (isActive != null) {
      whereClauses.add('is_active = ?');
      whereArgs.add(isActive ? 1 : 0);
    }
    final rows = await db.query(
      'subjects',
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at ASC',
    );
    return rows.map(_subjectFromRow).toList();
  }

  Future<void> updateSubject(Subject subject) async {
    final db = await _database.database;
    await db.update(
      'subjects',
      {
        'name': subject.name,
        'color': subject.color,
        'weight': subject.weight,
        'is_active': subject.isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [subject.id],
    );
  }

  Future<void> deleteSubject(int subjectId) async {
    final db = await _database.database;
    await db.delete('subjects', where: 'id = ?', whereArgs: [subjectId]);
  }

  Subject _subjectFromRow(Map<String, Object?> row) {
    return Subject(
      id: row['id'] as int,
      name: (row['name'] as String?) ?? '',
      color: (row['color'] as String?) ?? '#3554D1',
      weight: ((row['weight'] as num?) ?? 1.0).toDouble(),
      isActive: ((row['is_active'] as int?) ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Syllabus Topic CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertSyllabusTopic(SyllabusTopic topic) async {
    final db = await _database.database;
    return await db.insert('syllabus_topics', {
      'subject_id': topic.subjectId,
      'name': topic.name,
      'is_completed': topic.isCompleted ? 1 : 0,
      'total_questions': topic.totalQuestions,
      'covered_questions': topic.coveredQuestions,
    });
  }

  Future<List<SyllabusTopic>> listSyllabusTopics({int? subjectId}) async {
    final db = await _database.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];
    if (subjectId != null) {
      whereClauses.add('subject_id = ?');
      whereArgs.add(subjectId);
    }
    final rows = await db.query(
      'syllabus_topics',
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );
    return rows.map(_syllabusTopicFromRow).toList();
  }

  Future<void> updateSyllabusTopic(SyllabusTopic topic) async {
    final db = await _database.database;
    await db.update(
      'syllabus_topics',
      {
        'name': topic.name,
        'is_completed': topic.isCompleted ? 1 : 0,
        'total_questions': topic.totalQuestions,
        'covered_questions': topic.coveredQuestions,
      },
      where: 'id = ?',
      whereArgs: [topic.id],
    );
  }

  Future<void> deleteSyllabusTopic(int topicId) async {
    final db = await _database.database;
    await db.delete('syllabus_topics', where: 'id = ?', whereArgs: [topicId]);
  }

  SyllabusTopic _syllabusTopicFromRow(Map<String, Object?> row) {
    return SyllabusTopic(
      id: row['id'] as int,
      subjectId: (row['subject_id'] as int?) ?? 0,
      name: (row['name'] as String?) ?? '',
      isCompleted: ((row['is_completed'] as int?) ?? 0) == 1,
      totalQuestions: (row['total_questions'] as int?) ?? 0,
      coveredQuestions: (row['covered_questions'] as int?) ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Question-Topic Mapping
  // ---------------------------------------------------------------------------

  Future<void> linkQuestionToTopic(int questionId, int topicId) async {
    final db = await _database.database;
    await db.insert('question_topics', {
      'question_id': questionId,
      'topic_id': topicId,
    });
  }

  Future<List<int>> getTopicIdsForQuestion(int questionId) async {
    final db = await _database.database;
    final rows = await db.query(
      'question_topics',
      columns: ['topic_id'],
      where: 'question_id = ?',
      whereArgs: [questionId],
    );
    return rows.map((r) => (r['topic_id'] as int?) ?? 0).toList();
  }

  Future<List<int>> getQuestionIdsForTopic(int topicId) async {
    final db = await _database.database;
    final rows = await db.query(
      'question_topics',
      columns: ['question_id'],
      where: 'topic_id = ?',
      whereArgs: [topicId],
    );
    return rows.map((r) => (r['question_id'] as int?) ?? 0).toList();
  }

  // ---------------------------------------------------------------------------
  // Mock Test CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertMockTest(MockTest test) async {
    final db = await _database.database;
    return await db.insert('mock_tests', {
      'title': test.title,
      'exam_profile': test.examProfile,
      'subject_filter': test.subjectFilter,
      'topic_filter': test.topicFilter,
      'difficulty_filter': test.difficultyFilter,
      'question_count': test.questionCount,
      'duration_minutes': test.durationMinutes,
      'is_pyq_only': test.isPyqOnly ? 1 : 0,
      'created_at': test.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<List<MockTest>> listMockTests() async {
    final db = await _database.database;
    final rows = await db.query(
      'mock_tests',
      orderBy: 'created_at DESC',
    );
    return rows.map(_mockTestFromRow).toList();
  }

  Future<MockTest?> getMockTest(int testId) async {
    final db = await _database.database;
    final rows = await db.query(
      'mock_tests',
      where: 'id = ?',
      whereArgs: [testId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mockTestFromRow(rows.first);
  }

  Future<void> deleteMockTest(int testId) async {
    final db = await _database.database;
    await db.delete('mock_tests', where: 'id = ?', whereArgs: [testId]);
  }

  MockTest _mockTestFromRow(Map<String, Object?> row) {
    return MockTest(
      id: row['id'] as int,
      title: (row['title'] as String?) ?? '',
      examProfile: (row['exam_profile'] as String?) ?? '',
      subjectFilter: (row['subject_filter'] as String?),
      topicFilter: (row['topic_filter'] as String?),
      difficultyFilter: (row['difficulty_filter'] as String?),
      questionCount: (row['question_count'] as int?) ?? 0,
      durationMinutes: (row['duration_minutes'] as int?) ?? 0,
      isPyqOnly: ((row['is_pyq_only'] as int?) ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mock Test Attempt CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertMockTestAttempt(MockTestAttempt attempt) async {
    final db = await _database.database;
    return await db.insert('mock_test_attempts', {
      'test_id': attempt.testId,
      'score': attempt.score,
      'total': attempt.total,
      'percentage': attempt.percentage,
      'time_taken': attempt.timeTaken,
      'started_at': attempt.startedAt.millisecondsSinceEpoch,
      'completed_at':
          attempt.completedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> updateMockTestAttempt(MockTestAttempt attempt) async {
    final db = await _database.database;
    await db.update(
      'mock_test_attempts',
      {
        'score': attempt.score,
        'total': attempt.total,
        'percentage': attempt.percentage,
        'time_taken': attempt.timeTaken,
        'completed_at': attempt.completedAt?.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [attempt.id],
    );
  }

  Future<List<MockTestAttempt>> listMockTestAttempts({int? testId}) async {
    final db = await _database.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];
    if (testId != null) {
      whereClauses.add('test_id = ?');
      whereArgs.add(testId);
    }
    final rows = await db.query(
      'mock_test_attempts',
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'started_at DESC',
    );
    return rows.map(_mockTestAttemptFromRow).toList();
  }

  MockTestAttempt _mockTestAttemptFromRow(Map<String, Object?> row) {
    return MockTestAttempt(
      id: row['id'] as int,
      testId: (row['test_id'] as int?) ?? 0,
      score: (row['score'] as int?) ?? 0,
      total: (row['total'] as int?) ?? 0,
      percentage: ((row['percentage'] as num?) ?? 0).toDouble(),
      timeTaken: (row['time_taken'] as int?) ?? 0,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['started_at'] as int?) ?? 0,
      ),
      completedAt: (row['completed_at'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              row['completed_at'] as int,
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Attempt Answer CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertAttemptAnswer(AttemptAnswer answer) async {
    final db = await _database.database;
    return await db.insert('attempt_answers', {
      'attempt_id': answer.attemptId,
      'question_id': answer.questionId,
      'user_answer': answer.userAnswer,
      'is_correct': answer.isCorrect ? 1 : 0,
      'time_spent': answer.timeSpent,
    });
  }

  Future<List<AttemptAnswer>> listAttemptAnswers(int attemptId) async {
    final db = await _database.database;
    final rows = await db.query(
      'attempt_answers',
      where: 'attempt_id = ?',
      whereArgs: [attemptId],
      orderBy: 'id ASC',
    );
    return rows.map(_attemptAnswerFromRow).toList();
  }

  AttemptAnswer _attemptAnswerFromRow(Map<String, Object?> row) {
    return AttemptAnswer(
      id: row['id'] as int,
      attemptId: (row['attempt_id'] as int?) ?? 0,
      questionId: (row['question_id'] as int?) ?? 0,
      userAnswer: (row['user_answer'] as String?),
      isCorrect: ((row['is_correct'] as int?) ?? 0) == 1,
      timeSpent: (row['time_spent'] as int?) ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Question Explanation CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertQuestionExplanation(QuestionExplanation explanation) async {
    final db = await _database.database;
    return await db.insert('question_explanations', {
      'question_id': explanation.questionId,
      'language': explanation.language,
      'explanation': explanation.explanation,
      'source': explanation.source,
    });
  }

  Future<QuestionExplanation?> getQuestionExplanation(
    int questionId,
    String language,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'question_explanations',
      where: 'question_id = ? AND language = ?',
      whereArgs: [questionId, language],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _questionExplanationFromRow(rows.first);
  }

  Future<void> updateQuestionExplanation(QuestionExplanation explanation) async {
    final db = await _database.database;
    await db.update(
      'question_explanations',
      {
        'language': explanation.language,
        'explanation': explanation.explanation,
        'source': explanation.source,
      },
      where: 'id = ?',
      whereArgs: [explanation.id],
    );
  }

  Future<void> deleteQuestionExplanation(int explanationId) async {
    final db = await _database.database;
    await db.delete(
      'question_explanations',
      where: 'id = ?',
      whereArgs: [explanationId],
    );
  }

  QuestionExplanation _questionExplanationFromRow(Map<String, Object?> row) {
    return QuestionExplanation(
      id: row['id'] as int,
      questionId: (row['question_id'] as int?) ?? 0,
      language: (row['language'] as String?) ?? 'en',
      explanation: (row['explanation'] as String?) ?? '',
      source: (row['source'] as String?),
    );
  }

  /// Explanations joined with their question, newest first.
  ///
  /// [language] narrows the result to one language (`en` / `hi`); pass `null`
  /// for every language.
  Future<List<ExplanationEntry>> listExplanationEntries({
    String? language,
  }) async {
    final db = await _database.database;
    final where = language == null ? '' : 'WHERE e.language = ?';
    final args = language == null ? <Object?>[] : <Object?>[language];
    final rows = await db.rawQuery(
      '''
      SELECT
        e.id AS e_id, e.question_id AS e_question_id, e.language AS e_language,
        e.explanation AS e_explanation, e.source AS e_source,
        q.id AS q_id, q.paper_id AS q_paper_id, q.number AS q_number,
        q.text AS q_text, q.section AS q_section, q.options AS q_options,
        q.difficulty AS q_difficulty, q.importance AS q_importance,
        q.correct_option AS q_correct_option,
        q.is_pyq AS q_is_pyq, q.exam_year AS q_exam_year,
        q.exam_name AS q_exam_name, q.marks AS q_marks
      FROM question_explanations e
      JOIN questions q ON q.id = e.question_id
      $where
      ORDER BY e.id DESC
      ''',
      args,
    );
    return rows.map((row) {
      return ExplanationEntry(
        explanation: QuestionExplanation(
          id: (row['e_id'] as int?) ?? 0,
          questionId: (row['e_question_id'] as int?) ?? 0,
          language: (row['e_language'] as String?) ?? 'en',
          explanation: (row['e_explanation'] as String?) ?? '',
          source: row['e_source'] as String?,
        ),
        question: _questionRefFromRow(row),
      );
    }).toList();
  }

  /// Bookmarks joined with their question, newest bookmark first.
  Future<List<BookmarkEntry>> listBookmarkEntries() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT
        b.id AS b_id, b.question_id AS b_question_id,
        b.created_at AS b_created_at,
        q.id AS q_id, q.paper_id AS q_paper_id, q.number AS q_number,
        q.text AS q_text, q.section AS q_section, q.options AS q_options,
        q.difficulty AS q_difficulty, q.importance AS q_importance,
        q.correct_option AS q_correct_option,
        q.is_pyq AS q_is_pyq, q.exam_year AS q_exam_year,
        q.exam_name AS q_exam_name, q.marks AS q_marks
      FROM bookmarks b
      JOIN questions q ON q.id = b.question_id
      ORDER BY b.created_at DESC
    ''');
    return rows.map((row) {
      return BookmarkEntry(
        bookmark: Bookmark(
          id: (row['b_id'] as int?) ?? 0,
          questionId: (row['b_question_id'] as int?) ?? 0,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (row['b_created_at'] as int?) ?? 0,
          ),
        ),
        question: _questionRefFromRow(row),
      );
    }).toList();
  }

  /// Revision items due now, joined with their question, most overdue first.
  Future<List<RevisionEntry>> listDueRevisionEntries() async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      '''
      SELECT
        r.id AS r_id, r.question_id AS r_question_id,
        r.next_review AS r_next_review, r.interval_days AS r_interval_days,
        r.ease_factor AS r_ease_factor,
        q.id AS q_id, q.paper_id AS q_paper_id, q.number AS q_number,
        q.text AS q_text, q.section AS q_section, q.options AS q_options,
        q.difficulty AS q_difficulty, q.importance AS q_importance,
        q.correct_option AS q_correct_option,
        q.is_pyq AS q_is_pyq, q.exam_year AS q_exam_year,
        q.exam_name AS q_exam_name, q.marks AS q_marks
      FROM revision_schedule r
      JOIN questions q ON q.id = r.question_id
      WHERE r.next_review <= ?
      ORDER BY r.next_review ASC
      ''',
      [now],
    );
    return rows.map((row) {
      return RevisionEntry(
        item: RevisionItem(
          id: (row['r_id'] as int?) ?? 0,
          questionId: (row['r_question_id'] as int?) ?? 0,
          nextReview: DateTime.fromMillisecondsSinceEpoch(
            (row['r_next_review'] as int?) ?? 0,
          ),
          intervalDays: (row['r_interval_days'] as int?) ?? 1,
          easeFactor: ((row['r_ease_factor'] as num?) ?? 2.5).toDouble(),
        ),
        question: _questionRefFromRow(row),
      );
    }).toList();
  }

  /// Every question that belongs to a previous-year paper.
  ///
  /// A question counts as a PYQ when it is flagged `is_pyq`, or when either
  /// the question or its paper carries an exam year.
  Future<List<StoredQuestion>> listPyqQuestions() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT q.*, p.exam_year AS paper_exam_year,
             p.exam_name AS paper_exam_name
      FROM questions q
      JOIN papers p ON p.id = q.paper_id
      WHERE q.is_pyq = 1
         OR q.exam_year IS NOT NULL
         OR p.exam_year IS NOT NULL
      ORDER BY COALESCE(q.exam_year, p.exam_year) DESC,
               q.paper_id ASC, q.order_index ASC
    ''');
    return rows.map((row) {
      final question = _questionFromRow(row);
      return question.copyWith(
        examYear: question.examYear ??
            (row['paper_exam_year'] as int?),
        examName: question.examName ??
            (row['paper_exam_name'] as String?),
        isPyq: true,
      );
    }).toList();
  }

  /// Ids of every question that has at least one recorded attempt answer.
  Future<Set<int>> getAnsweredQuestionIds() async {
    final db = await _database.database;
    final rows = await db.query(
      'attempt_answers',
      columns: ['question_id'],
      distinct: true,
    );
    return rows.map((row) => (row['question_id'] as int?) ?? 0).toSet();
  }

  QuestionRef _questionRefFromRow(Map<String, Object?> row) {
    return QuestionRef(
      id: (row['q_id'] as int?) ?? 0,
      paperId: (row['q_paper_id'] as int?) ?? 0,
      number: (row['q_number'] as String?) ?? '',
      text: (row['q_text'] as String?) ?? '',
      section: (row['q_section'] as String?) ?? '',
      options: _decodeOptions(row['q_options'] as String?),
      difficulty: (row['q_difficulty'] as String?) ?? 'Medium',
      importance: (row['q_importance'] as String?) ?? 'Medium',
      isPyq: ((row['q_is_pyq'] as int?) ?? 0) == 1,
      examYear: row['q_exam_year'] as int?,
      examName: row['q_exam_name'] as String?,
      marks: (row['q_marks'] as num?)?.toDouble(),
    );
  }

  // ---------------------------------------------------------------------------
  // Bookmark CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertBookmark(Bookmark bookmark) async {
    final db = await _database.database;
    return await db.insert('bookmarks', {
      'question_id': bookmark.questionId,
      'created_at': bookmark.createdAt.millisecondsSinceEpoch,
    });
  }

  Future<List<Bookmark>> listBookmarks() async {
    final db = await _database.database;
    final rows = await db.query(
      'bookmarks',
      orderBy: 'created_at DESC',
    );
    return rows.map(_bookmarkFromRow).toList();
  }

  Future<bool> isBookmarked(int questionId) async {
    final db = await _database.database;
    final rows = await db.query(
      'bookmarks',
      where: 'question_id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> deleteBookmark(int questionId) async {
    final db = await _database.database;
    await db.delete('bookmarks', where: 'question_id = ?', whereArgs: [questionId]);
  }

  Bookmark _bookmarkFromRow(Map<String, Object?> row) {
    return Bookmark(
      id: row['id'] as int,
      questionId: (row['question_id'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Revision Schedule CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertRevisionItem(RevisionItem item) async {
    final db = await _database.database;
    return await db.insert('revision_schedule', {
      'question_id': item.questionId,
      'next_review': item.nextReview.millisecondsSinceEpoch,
      'interval_days': item.intervalDays,
      'ease_factor': item.easeFactor,
    });
  }

  /// Replaces any existing schedule for the question with [item].
  Future<void> upsertRevisionItem(RevisionItem item) async {
    final db = await _database.database;
    await db.delete(
      'revision_schedule',
      where: 'question_id = ?',
      whereArgs: [item.questionId],
    );
    await db.insert('revision_schedule', {
      'question_id': item.questionId,
      'next_review': item.nextReview.millisecondsSinceEpoch,
      'interval_days': item.intervalDays,
      'ease_factor': item.easeFactor,
    });
  }

  Future<List<RevisionItem>> listDueRevisions() async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'revision_schedule',
      where: 'next_review <= ?',
      whereArgs: [now],
      orderBy: 'next_review ASC',
    );
    return rows.map(_revisionItemFromRow).toList();
  }

  Future<void> updateRevisionItem(RevisionItem item) async {
    final db = await _database.database;
    await db.update(
      'revision_schedule',
      {
        'next_review': item.nextReview.millisecondsSinceEpoch,
        'interval_days': item.intervalDays,
        'ease_factor': item.easeFactor,
      },
      where: 'question_id = ?',
      whereArgs: [item.questionId],
    );
  }

  RevisionItem _revisionItemFromRow(Map<String, Object?> row) {
    return RevisionItem(
      id: row['id'] as int,
      questionId: (row['question_id'] as int?) ?? 0,
      nextReview: DateTime.fromMillisecondsSinceEpoch(
        (row['next_review'] as int?) ?? 0,
      ),
      intervalDays: (row['interval_days'] as int?) ?? 1,
      easeFactor: ((row['ease_factor'] as num?) ?? 2.5).toDouble(),
    );
  }
}
