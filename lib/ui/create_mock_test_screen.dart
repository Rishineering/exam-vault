import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_strings.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'mock_test_screen.dart';

/// Create a new mock test screen.
///
/// Users configure subject, topic, difficulty, question count, duration and
/// whether to include PYQ-only questions.
class CreateMockTestScreen extends StatefulWidget {
  const CreateMockTestScreen({super.key});

  @override
  State<CreateMockTestScreen> createState() => _CreateMockTestScreenState();
}

class _CreateMockTestScreenState extends State<CreateMockTestScreen> {
  final _titleController = TextEditingController();
  String _selectedSubject = 'All Subjects';
  String _selectedDifficulty = 'All Difficulties';
  bool _pyqOnly = false;
  int _questionCount = 50;
  int _durationMinutes = 60;
  bool _loadingSubjects = true;
  List<Subject> _subjects = const [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final state = AppScope.read(context);
    await state.loadSubjects();
    if (!mounted) return;
    setState(() {
      _subjects = state.subjects;
      _loadingSubjects = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _startTest(AppState state, AppText t) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.isHindi ? 'कृपया एक शीर्षक दर्ज करें' : 'Please enter a test title',
          ),
        ),
      );
      return;
    }

    final test = MockTest(
      id: 0,
      title: title,
      examProfile: state.userProfile?.targetExam ?? 'General',
      subjectFilter:
          _selectedSubject == 'All Subjects' ? null : _selectedSubject,
      topicFilter: null,
      difficultyFilter: _selectedDifficulty == 'All Difficulties'
          ? null
          : _selectedDifficulty,
      questionCount: _questionCount,
      durationMinutes: _durationMinutes,
      isPyqOnly: _pyqOnly,
      createdAt: DateTime.now(),
    );

    final testId = await state.createMockTest(test);

    // Create an attempt
    final attempt = MockTestAttempt(
      id: 0,
      testId: testId,
      score: 0,
      total: _questionCount,
      percentage: 0,
      timeTaken: 0,
      startedAt: DateTime.now(),
      completedAt: null,
    );
    final attemptId = await state.startMockTestAttempt(attempt);

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MockTestScreen(
          testId: testId,
          attemptId: attemptId,
          questionCount: _questionCount,
          durationMinutes: _durationMinutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppText.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.createMockTest),
        centerTitle: false,
      ),
      body: _loadingSubjects
          ? const Center(child: CircularProgressIndicator())
          : Form(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    t.testConfiguration,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: t.testTitle,
                      hintText: t.isHindi
                          ? 'उदा. भारतीय राजव्यवस्था मॉक टेस्ट 1'
                          : 'e.g. Polity Mock Test 1',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return t.isHindi
                            ? 'कृपया शीर्षक दर्ज करें'
                            : 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Subject filter
                  Text(
                    t.subjectName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    value: _selectedSubject,
                    items: [
                      DropdownMenuItem(
                        value: 'All Subjects',
                        child: Text(t.allSubjects),
                      ),
                      ..._subjects.map(
                        (s) => DropdownMenuItem(
                          value: s.name,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedSubject = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Difficulty filter
                  Text(
                    t.difficulty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    value: _selectedDifficulty,
                    items: [
                      DropdownMenuItem(
                        value: 'All Difficulties',
                        child: Text(t.allDifficulties),
                      ),
                      DropdownMenuItem(
                        value: 'Easy',
                        child: Text(t.easy),
                      ),
                      DropdownMenuItem(
                        value: 'Medium',
                        child: Text(t.medium),
                      ),
                      DropdownMenuItem(
                        value: 'Hard',
                        child: Text(t.hard),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDifficulty = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // PYQ only toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.pyqOnlyToggle),
                    subtitle: Text(t.pyqOnlySubtitle),
                    trailing: Switch(
                      value: _pyqOnly,
                      onChanged: (val) => setState(() => _pyqOnly = val),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Question count
                  Text(
                    t.numberOfQuestions,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _questionCount.toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t.numberOfQuestions,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (val) {
                            final v = int.tryParse(val);
                            if (v != null && v > 0 && v <= 200) {
                              setState(() => _questionCount = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Duration
                  Text(
                    t.durationMinutes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _durationMinutes.toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t.durationMinutes,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (val) {
                            final v = int.tryParse(val);
                            if (v != null && v > 0 && v <= 600) {
                              setState(() => _durationMinutes = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        final form = Form.of(context);
                        if (form.validate()) {
                          _startTest(AppScope.read(context), t);
                        }
                      },
                      child: Text(
                        t.startTest,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
