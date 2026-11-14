import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/parsing/question_parser.dart';
import '../data/models.dart';
import '../data/paper_repository.dart';
import '../services/document_reader.dart';
import '../services/export_service.dart';
import '../services/question_generation_service.dart';

/// Application-wide state: the list of imported papers plus the import and
/// edit operations used by the UI.
class AppState extends ChangeNotifier {
  AppState({
    PaperRepository? repository,
    this.reader = const DocumentReader(),
    this.parser = const QuestionParser(),
    this.exporter = const ExportService(),
    QuestionGenerationPipeline? generationPipeline,
  }) : _repository = repository ?? PaperRepository() {
    this.generationPipeline =
        generationPipeline ?? QuestionGenerationPipeline(repository: _repository);
  }

  final PaperRepository _repository;
  final DocumentReader reader;
  final QuestionParser parser;
  final ExportService exporter;
  late final QuestionGenerationPipeline generationPipeline;

  List<PaperRecord> _papers = const [];
  bool _loading = false;
  String? _loadError;
  bool _isGenerating = false;
  String? _generationError;
  GenerationResult? _lastGenerationResult;

  // --- Exam profile ---
  UserProfile? _userProfile;
  bool _profileLoading = false;

  // --- Subjects & syllabus ---
  List<Subject> _subjects = const [];
  List<SyllabusTopic> _syllabusTopics = const [];

  // --- Mock tests ---
  List<MockTest> _mockTests = const [];
  List<MockTestAttempt> _mockTestAttempts = const [];
  bool _isInMockTest = false;
  MockTestAttempt? _currentAttempt;

  // --- Analytics ---
  bool _isLoadingAnalytics = false;

  // --- Bookmarks ---
  List<Bookmark> _bookmarks = const [];

  // --- Revisions ---
  List<RevisionItem> _dueRevisions = const [];

  List<PaperRecord> get papers => _papers;
  bool get loading => _loading;
  String? get loadError => _loadError;

  /// Whether a generation run is currently in progress.
  bool get isGenerating => _isGenerating;

  /// Error from the last generation attempt, if any.
  String? get generationError => _generationError;

  /// Result of the last successful generation run, if any.
  GenerationResult? get lastGenerationResult => _lastGenerationResult;

  /// Configures the LLM API key. Call this before [generateQuestions].
  void setLLMApiKey(String apiKey) {
    generationPipeline.setApiKey(apiKey);
  }

  /// Configures a custom LLM endpoint (optional).
  void setLLMEndpoint(String baseUrl, {String? model}) {
    generationPipeline.setEndpoint(baseUrl, model: model);
  }

  /// Returns whether the LLM API key has been configured.
  bool get isLLMConfigured => generationPipeline.isConfigured;

  // --- Exam profile getters ---
  UserProfile? get userProfile => _userProfile;
  bool get profileLoading => _profileLoading;
  bool get isProfileSetup => _userProfile?.profileSetup ?? false;

  // --- Subjects getters ---
  List<Subject> get subjects => _subjects;
  List<Subject> get activeSubjects =>
      _subjects.where((s) => s.isActive).toList();

  // --- Syllabus getters ---
  List<SyllabusTopic> get syllabusTopics => _syllabusTopics;

  /// Overall syllabus completion percentage across all active subjects.
  double get syllabusCompletionPercent {
    if (_syllabusTopics.isEmpty) return 0.0;
    final total = _syllabusTopics.fold<int>(
      0,
      (sum, t) => sum + t.totalQuestions,
    );
    if (total == 0) return 0.0;
    final covered = _syllabusTopics.fold<int>(
      0,
      (sum, t) => sum + t.coveredQuestions,
    );
    return (covered / total) * 100;
  }

  // --- Mock test getters ---
  List<MockTest> get mockTests => _mockTests;
  List<MockTestAttempt> get mockTestAttempts => _mockTestAttempts;
  bool get isInMockTest => _isInMockTest;
  MockTestAttempt? get currentAttempt => _currentAttempt;

  // --- Analytics getters ---
  bool get isLoadingAnalytics => _isLoadingAnalytics;

  // --- Bookmarks getters ---
  List<Bookmark> get bookmarks => _bookmarks;

  // --- Revisions getters ---
  List<RevisionItem> get dueRevisions => _dueRevisions;
  int get dueRevisionCount => _dueRevisions.length;

  int get totalQuestions =>
      _papers.fold(0, (sum, paper) => sum + paper.questionCount);

  int get totalNeedsReview =>
      _papers.fold(0, (sum, paper) => sum + paper.reviewCount);

  Future<void> refresh() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _papers = await _repository.listPapers();
    } catch (error) {
      _loadError = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<int> importFile(
    SelectedFile file, {
    void Function(ImportProgress progress)? onProgress,
  }) async {
    final document = await reader.read(file, onProgress: onProgress);

    onProgress?.call(const ImportProgress(stage: ImportStage.parsing));
    final result = parser.parse(document);

    if (result.questions.isEmpty) {
      throw const FormatException(
        'No questions could be extracted. The file may be empty, encrypted or '
        'contain only images. Try a clearer PDF or paste the text as a .txt file.',
      );
    }

    onProgress?.call(const ImportProgress(stage: ImportStage.saving));
    final paperId = await _repository.insertParsedPaper(
      result: result,
      fileName: file.name,
    );

    onProgress?.call(const ImportProgress(stage: ImportStage.done));
    await refresh();
    return paperId;
  }

  Future<PaperDetail?> loadPaper(int paperId) =>
      _repository.getPaperDetail(paperId);

  Future<void> saveQuestion(StoredQuestion question) async {
    await _repository.updateQuestion(question);
    await refresh();
  }

  Future<void> renamePaper(int paperId, String title) async {
    await _repository.renamePaper(paperId, title);
    await refresh();
  }

  Future<void> deletePaper(int paperId) async {
    await _repository.deletePaper(paperId);
    await refresh();
  }

  Future<void> exportPaper(PaperDetail detail) async {
    await exporter.shareCsv(detail);
  }

  /// Default categories shown on the home screen.
  static const List<String> homeCategories = [
    'History',
    'Geography',
    'Social Science',
    'Maths',
  ];

  /// Returns the top questions for each home category.
  ///
  /// [perCategory] is used for the first three categories and [mathsLimit] for
  /// Maths, so the default call yields 10 questions (3 + 3 + 3 + 1).
  Future<Map<String, List<StoredQuestion>>> getTopQuestionsByCategory({
    int perCategory = 3,
    int mathsLimit = 1,
  }) async {
    final result = <String, List<StoredQuestion>>{};
    for (final category in homeCategories) {
      final limit = category == 'Maths' ? mathsLimit : perCategory;
      result[category] = await _repository.getQuestionsByCategory(
        category,
        limit: limit,
      );
    }
    return result;
  }

  /// Returns true if the user has completed onboarding / login at least once.
  Future<bool> isOnboardingComplete() async {
    final value = await _repository.getSetting('onboarding_complete');
    return value == '1';
  }

  /// Marks onboarding / login as completed so the welcome/login screens are
  /// skipped on subsequent launches.
  Future<void> setOnboardingComplete() async {
    await _repository.setSetting('onboarding_complete', '1');
  }

  /// Runs the LLM question generation pipeline: collects up to 100 reference
  /// questions, generates 500 new ones, and stores them in the database.
  ///
  /// Requires [setLLMApiKey] to have been called first.
  Future<GenerationResult> generateQuestions() async {
    _isGenerating = true;
    _generationError = null;
    notifyListeners();
    try {
      final result = await generationPipeline.generate();
      _lastGenerationResult = result;
      notifyListeners();
      return result;
    } catch (error) {
      _generationError = error.toString();
      notifyListeners();
      rethrow;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  /// Returns all generated questions, optionally filtered by batch/category.
  Future<List<GeneratedQuestion>> getGeneratedQuestions({
    String? generationBatch,
    String? category,
    int? limit,
  }) async {
    return _repository.listGeneratedQuestions(
      generationBatch: generationBatch,
      category: category,
      limit: limit,
    );
  }

  /// Returns the count of generated questions, optionally filtered.
  Future<int> getGeneratedQuestionCount({
    String? generationBatch,
    String? category,
  }) async {
    return _repository.countGeneratedQuestions(
      generationBatch: generationBatch,
      category: category,
    );
  }

  /// Returns every distinct generation batch id, newest first.
  Future<List<String>> getGeneratedQuestionBatches() async {
    return _repository.getGeneratedQuestionBatches();
  }

  /// Returns every distinct category currently stored in the database.
  Future<List<String>> getStoredCategories() => _repository.getCategories();

  /// Seeds the database with dummy questions if no papers exist yet.
  Future<void> seedIfEmpty() => _repository.seedIfEmpty();

  // ---------------------------------------------------------------------------
  // Exam Profile
  // ---------------------------------------------------------------------------

  Future<void> loadUserProfile() async {
    _profileLoading = true;
    notifyListeners();
    try {
      _userProfile = await _repository.getUserProfile();
    } finally {
      _profileLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _repository.insertUserProfile(profile);
    _userProfile = profile;
    notifyListeners();
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await _repository.updateUserProfile(profile);
    _userProfile = profile;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Subjects
  // ---------------------------------------------------------------------------

  Future<void> loadSubjects() async {
    _subjects = await _repository.listSubjects();
    notifyListeners();
  }

  Future<int> addSubject(Subject subject) async {
    final id = await _repository.insertSubject(subject);
    await loadSubjects();
    return id;
  }

  Future<void> updateSubject(Subject subject) async {
    await _repository.updateSubject(subject);
    await loadSubjects();
  }

  Future<void> removeSubject(int subjectId) async {
    await _repository.deleteSubject(subjectId);
    await loadSubjects();
    await loadSyllabusTopics();
  }

  // ---------------------------------------------------------------------------
  // Syllabus Topics
  // ---------------------------------------------------------------------------

  Future<void> loadSyllabusTopics({int? subjectId}) async {
    _syllabusTopics = await _repository.listSyllabusTopics(
      subjectId: subjectId,
    );
    notifyListeners();
  }

  Future<int> addSyllabusTopic(SyllabusTopic topic) async {
    final id = await _repository.insertSyllabusTopic(topic);
    await loadSyllabusTopics(subjectId: topic.subjectId);
    return id;
  }

  Future<void> updateSyllabusTopic(SyllabusTopic topic) async {
    await _repository.updateSyllabusTopic(topic);
    await loadSyllabusTopics(subjectId: topic.subjectId);
  }

  Future<void> removeSyllabusTopic(int topicId) async {
    final topic = _syllabusTopics.firstWhere((t) => t.id == topicId);
    await _repository.deleteSyllabusTopic(topicId);
    await loadSyllabusTopics(subjectId: topic.subjectId);
  }

  /// Recalculates syllabus topic coverage from stored questions.
  Future<void> recalculateSyllabusCoverage() async {
    for (final topic in _syllabusTopics) {
      final questionIds = await _repository.getQuestionIdsForTopic(topic.id);
      final total = questionIds.length;
      // Count covered as questions that have been answered in an attempt
      // or have needs_review = 0 (reviewed)
      int covered = 0;
      for (final qid in questionIds) {
        final questions = await _repository.getQuestions(0); // placeholder
        // We'll compute coverage from attempts instead
      }
      await _repository.updateSyllabusTopic(
        topic.copyWith(totalQuestions: total, coveredQuestions: covered),
      );
    }
    await loadSyllabusTopics();
  }

  // ---------------------------------------------------------------------------
  // Mock Tests
  // ---------------------------------------------------------------------------

  Future<void> loadMockTests() async {
    _mockTests = await _repository.listMockTests();
    notifyListeners();
  }

  Future<int> createMockTest(MockTest test) async {
    final id = await _repository.insertMockTest(test);
    await loadMockTests();
    return id;
  }

  Future<void> deleteMockTest(int testId) async {
    await _repository.deleteMockTest(testId);
    await loadMockTests();
  }

  Future<void> loadMockTestAttempts({int? testId}) async {
    _mockTestAttempts = await _repository.listMockTestAttempts(testId: testId);
    notifyListeners();
  }

  Future<int> startMockTestAttempt(MockTestAttempt attempt) async {
    final id = await _repository.insertMockTestAttempt(attempt);
    _currentAttempt = attempt.copyWith(id: id);
    _isInMockTest = true;
    notifyListeners();
    return id;
  }

  Future<void> submitMockTestAttempt({
    required int attemptId,
    required int score,
    required int total,
    required int timeTaken,
    required List<AttemptAnswer> answers,
  }) async {
    final now = DateTime.now();
    final percentage = total == 0 ? 0.0 : (score / total) * 100;

    await _repository.insertMockTestAttempt(
      MockTestAttempt(
        id: attemptId,
        testId: _currentAttempt?.testId ?? 0,
        score: score,
        total: total,
        percentage: percentage,
        timeTaken: timeTaken,
        startedAt: _currentAttempt?.startedAt ?? now,
        completedAt: now,
      ),
    );

    // Save all answers
    final batch = <Future<void>>[];
    for (final answer in answers) {
      batch.add(_repository.insertAttemptAnswer(answer));

      // Update revision schedule based on correctness
      if (answer.isCorrect) {
        // Increase interval (easy)
        // For now, just mark as reviewed
      } else {
        // Decrease interval (hard, review soon)
      }
    }
    await Future.wait(batch);

    await loadMockTestAttempts();
    _isInMockTest = false;
    _currentAttempt = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------

  Future<void> loadBookmarks() async {
    _bookmarks = await _repository.listBookmarks();
    notifyListeners();
  }

  Future<void> toggleBookmark(int questionId) async {
    final already = await _repository.isBookmarked(questionId);
    if (already) {
      await _repository.deleteBookmark(questionId);
    } else {
      await _repository.insertBookmark(
        Bookmark(
          id: 0,
          questionId: questionId,
          createdAt: DateTime.now(),
        ),
      );
    }
    await loadBookmarks();
  }

  Future<bool> isQuestionBookmarked(int questionId) async {
    return await _repository.isBookmarked(questionId);
  }

  // ---------------------------------------------------------------------------
  // Revisions (Spaced Repetition)
  // ---------------------------------------------------------------------------

  Future<void> loadDueRevisions() async {
    _dueRevisions = await _repository.listDueRevisions();
    notifyListeners();
  }

  Future<void> updateRevisionSchedule(RevisionItem item) async {
    await _repository.updateRevisionItem(item);
    await loadDueRevisions();
  }

  // ---------------------------------------------------------------------------
  // Analytics
  // ---------------------------------------------------------------------------

  /// Accuracy by subject from all mock test attempts.
  Future<Map<String, double>> getAccuracyBySubject() async {
    final result = <String, double>{};
    // Simplified: compute from all attempts
    for (final attempt in _mockTestAttempts) {
      final answers = await _repository.listAttemptAnswers(attempt.id);
      if (answers.isEmpty) continue;
      final correct = answers.where((a) => a.isCorrect).length;
      final acc = (correct / answers.length) * 100;
      // We'd need to map questions to subjects; for now use attempt's test
      final test = _mockTests.firstWhere(
        (t) => t.id == attempt.testId,
        orElse: () => _mockTests.first,
      );
      result[test.examProfile] = acc;
    }
    return result;
  }

  /// Weak areas: topics with accuracy below threshold.
  Future<List<String>> getWeakAreas({double threshold = 50.0}) async {
    final weak = <String>[];
    final accuracy = await getAccuracyBySubject();
    accuracy.forEach((subject, acc) {
      if (acc < threshold) weak.add(subject);
    });
    return weak;
  }

  /// Overall accuracy across all attempts.
  Future<double> getOverallAccuracy() async {
    if (_mockTestAttempts.isEmpty) return 0.0;
    double sum = 0;
    for (final attempt in _mockTestAttempts) {
      sum += attempt.percentage;
    }
    return sum / _mockTestAttempts.length;
  }

  /// Total time spent in mock tests (minutes).
  Future<int> getTotalStudyTimeMinutes() async {
    int total = 0;
    for (final a in _mockTestAttempts) {
      total += a.timeTaken;
    }
    return total;
  }

  Future<String> writeCsv(PaperDetail detail) async {
    final file = await exporter.writeCsv(detail);
    return file.path;
  }

  static ParsedQuestion toParsed(StoredQuestion question) => question.toParsed();
}
