import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'mock_test_results_screen.dart';

/// Mock test taking screen with timer.
class MockTestScreen extends StatefulWidget {
  final int testId;
  final int attemptId;
  final int questionCount;
  final int durationMinutes;

  const MockTestScreen({
    super.key,
    required this.testId,
    required this.attemptId,
    required this.questionCount,
    required this.durationMinutes,
  });

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  List<StoredQuestion> _questions = [];
  int _currentIndex = 0;
  int _timeRemaining = 0;
  Timer? _timer;
  final Map<int, String> _userAnswers = {};
  final Map<int, int> _timeSpent = {};
  final Map<int, DateTime> _questionStartTimes = {};
  bool _submitted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _timeRemaining = widget.durationMinutes * 60;
    _loadQuestions();
    _startTimer();
  }

  Future<void> _loadQuestions() async {
    final state = AppScope.read(context);
    final genQuestions = await state.getGeneratedQuestions(
      limit: widget.questionCount,
    );
    final allQuestions = genQuestions.map((gq) => StoredQuestion(
      id: gq.id,
      paperId: 0,
      number: gq.number,
      orderIndex: 0,
      text: gq.text,
      section: gq.section,
      marks: gq.marks,
      options: gq.options,
      pageNumber: gq.pageNumber,
      category: gq.category,
      difficulty: 'Medium',
      importance: 'Medium',
      isPyq: false,
      examYear: null,
      examName: null,
      confidence: gq.confidence,
      needsReview: gq.needsReview,
      warnings: const [],
      rawBlock: gq.rawBlock,
    )).toList();

    if (!mounted) return;
    setState(() {
      _questions = allQuestions.take(widget.questionCount).toList();
      _loading = false;
    });
    if (_questions.isNotEmpty) {
      _questionStartTimes[_questions[_currentIndex].id] = DateTime.now();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          _submitTest();
        }
      });
    });
  }

  void _recordTimeSpent() {
    final start = _questionStartTimes[_questions[_currentIndex].id];
    if (start != null) {
      final spent = DateTime.now().difference(start).inSeconds;
      _timeSpent[_questions[_currentIndex].id] =
          (_timeSpent[_questions[_currentIndex].id] ?? 0) + spent;
    }
    _questionStartTimes[_questions[_currentIndex].id] = DateTime.now();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submitTest() async {
    _recordTimeSpent();
    _timer?.cancel();

    int score = 0;
    for (final q in _questions) {
      final answer = _userAnswers[q.id];
      if (answer != null && answer.isNotEmpty) {
        score++;
      }
    }

    final answers = _questions.map((q) {
      return AttemptAnswer(
        id: 0,
        attemptId: widget.attemptId,
        questionId: q.id,
        userAnswer: _userAnswers[q.id],
        isCorrect: _userAnswers[q.id] != null &&
            _userAnswers[q.id]!.isNotEmpty,
        timeSpent: _timeSpent[q.id] ?? 0,
      );
    }).toList();

    if (!mounted) return;
    setState(() => _submitted = true);

    final state = AppScope.read(context);
    await state.submitMockTestAttempt(
      attemptId: widget.attemptId,
      score: score,
      total: _questions.length,
      timeTaken: widget.durationMinutes * 60 - _timeRemaining,
      answers: answers,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MockTestResultsScreen(
          testId: widget.testId,
          attemptId: widget.attemptId,
          score: score,
          total: _questions.length,
          timeTaken: widget.durationMinutes * 60 - _timeRemaining,
        ),
      ),
    );
  }

  void _selectAnswer(String answer) {
    _recordTimeSpent();
    setState(() {
      _userAnswers[_questions[_currentIndex].id] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_submitted) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Submitting test...'),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mock Test'), centerTitle: false),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_rounded,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No questions available',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Import a paper or generate questions first.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final answered = _userAnswers[q.id] != null;

    final children = <Widget>[
      LinearProgressIndicator(
        value: (_currentIndex + 1) / _questions.length,
        minHeight: 4,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    q.number,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                q.text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (q.options.isNotEmpty) ...[
                ...q.options.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final opt = entry.value;
                  final label = String.fromCharCode(
                    'A'.codeUnitAt(0) + idx,
                  );
                  final isSelected = _userAnswers[q.id] == label;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _selectAnswer(label),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: scheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isSelected
                                  ? scheme.primary
                                  : Colors.transparent,
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                opt.text,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ));  // closes InkWell + return Container
                  }).toList(),
              ] else
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Your Answer',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  onChanged: (val) => _selectAnswer(val),
                ),
            ],
          ),
        ),
      ),
    ];

    if (answered) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Answer saved',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green,
            ),
          ),
        ),
      );
    }

    children.addAll([
      const SizedBox(height: 24),
      Row(
        children: [
          if (_currentIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevQuestion,
                child: const Text('Previous'),
              ),
            ),
          if (_currentIndex > 0) const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: (_currentIndex < _questions.length - 1)
                  ? _nextQuestion
                  : _submitTest,
              child: Text(
                _currentIndex < _questions.length - 1
                    ? 'Next'
                    : 'Submit Test',
              ),
            ),
          ),
        ],
      ),
    ]);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Question ${_currentIndex + 1}/${_questions.length}',
          ),
          centerTitle: false,
          actions: [
            Text(
              _formatTime(_timeRemaining),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: _timeRemaining < 60
                    ? scheme.error
                    : scheme.onSurface,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: children,
        ),
      ),
    );
  }
}
