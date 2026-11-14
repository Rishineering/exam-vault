import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/parsing/question_parser.dart';
import '../data/models.dart';
import '../data/paper_repository.dart';
import '../services/document_reader.dart';
import '../services/export_service.dart';

/// Application-wide state: the list of imported papers plus the import and
/// edit operations used by the UI.
class AppState extends ChangeNotifier {
  AppState({
    PaperRepository? repository,
    this.reader = const DocumentReader(),
    this.parser = const QuestionParser(),
    this.exporter = const ExportService(),
  }) : _repository = repository ?? PaperRepository();

  final PaperRepository _repository;
  final DocumentReader reader;
  final QuestionParser parser;
  final ExportService exporter;

  List<PaperRecord> _papers = const [];
  bool _loading = false;
  String? _loadError;

  List<PaperRecord> get papers => _papers;
  bool get loading => _loading;
  String? get loadError => _loadError;

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

  /// Returns every distinct category currently stored in the database.
  Future<List<String>> getStoredCategories() => _repository.getCategories();

  /// Seeds the database with dummy questions if no papers exist yet.
  Future<void> seedIfEmpty() => _repository.seedIfEmpty();

  Future<String> writeCsv(PaperDetail detail) async {
    final file = await exporter.writeCsv(detail);
    return file.path;
  }

  static ParsedQuestion toParsed(StoredQuestion question) => question.toParsed();
}
