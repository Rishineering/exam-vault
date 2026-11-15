import 'package:exam_vault/core/models.dart';

/// Dummy seed data for the home screen categories.
///
/// Provides 10 questions across 4 categories:
///   - History: 3 questions
///   - Geography: 3 questions
///   - Social Science: 3 questions
///   - Maths:   1 question
///
/// Total: 10 questions, matching the home screen "Top questions" layout.
class DummyData {
  DummyData._();

  static const List<Map<String, dynamic>> questions = [
    {
      'number': '1',
      'orderIndex': 0,
      'correctOption': 'A',
      'text': 'Who was the first President of the United States?',
      'section': 'Section A',
      'marks': 2,
      'pageNumber': 1,
      'category': 'History',
      'confidence': 0.95,
      'needsReview': false,
      'options': [
        {'label': 'A', 'text': 'George Washington'},
        {'label': 'B', 'text': 'Thomas Jefferson'},
        {'label': 'C', 'text': 'Abraham Lincoln'},
        {'label': 'D', 'text': 'John Adams'},
      ],
    },
    {
      'number': '2',
      'orderIndex': 1,
      'correctOption': 'B',
      'text': 'In which year did India gain independence?',
      'section': 'Section A',
      'marks': 2,
      'pageNumber': 1,
      'category': 'History',
      'confidence': 0.92,
      'needsReview': false,
      'options': [
        {'label': 'A', 'text': '1945'},
        {'label': 'B', 'text': '1947'},
        {'label': 'C', 'text': '1950'},
        {'label': 'D', 'text': '1942'},
      ],
    },
    {
      'number': '3',
      'orderIndex': 2,
      'correctOption': 'C',
      'text': "Which river is known as the 'Sorrow of Bihar'?",
      'section': 'Section A',
      'marks': 2,
      'pageNumber': 1,
      'category': 'History',
      'confidence': 0.9,
      'needsReview': false,
      'options': [
        {'label': 'A', 'text': 'Ganga'},
        {'label': 'B', 'text': 'Yamuna'},
        {'label': 'C', 'text': 'Kosi'},
        {'label': 'D', 'text': 'Brahmaputra'},
      ],
    },
    {
      'number': '4',
      'orderIndex': 3,
      'correctOption': 'C',
      'text': 'What is the capital of Australia?',
      'section': 'Section B',
      'marks': 2,
      'pageNumber': 1,
      'category': 'Geography',
      'confidence': 0.94,
      'needsReview': false,
      'options': [
        {'label': 'A', 'text': 'Sydney'},
        {'label': 'B', 'text': 'Melbourne'},
        {'label': 'C', 'text': 'Canberra'},
        {'label': 'D', 'text': 'Perth'},
      ],
    },
    {
      'number': '5',
      'orderIndex': 4,
      'correctOption': 'B',
      'text': 'Which is the largest continent by land area?',
      'section': 'Section B',
      'marks': 2,
      'pageNumber': 1,
      'category': 'Geography',
      'confidence': 0.91,
      'needsReview': false,
      'options': [
        {'label': 'A', 'text': 'Africa'},
        {'label': 'B', 'text': 'Asia'},
        {'label': 'C', 'text': 'North America'},
        {'label': 'D', 'text': 'Europe'},
      ],
    },
    {
      'number': '6',
      'orderIndex': 5,
      'correctOption': 'B',
      'text': 'The Sahara Desert is located in which continent?',
      'section': 'Section B',
      'marks': 2,
      'pageNumber': 1,
      'category': 'Geography',
      'confidence': 0.89,
      'needsReview': false,
      'options': [
        {'label': 'A', 'text': 'Asia'},
        {'label': 'B', 'text': 'Africa'},
        {'label': 'C', 'text': 'Australia'},
        {'label': 'D', 'text': 'South America'},
      ],
    },
    {
      'number': '7',
      'orderIndex': 6,
      'text': 'What are the three tiers of the Panchayati Raj system?',
      'section': 'Section C',
      'marks': 3,
      'pageNumber': 1,
      'category': 'Social Science',
      'confidence': 0.88,
      'needsReview': false,
      'options': [],
    },
    {
      'number': '8',
      'orderIndex': 7,
      'text': 'Describe the fundamental rights guaranteed by the Constitution of India.',
      'section': 'Section C',
      'marks': 5,
      'pageNumber': 1,
      'category': 'Social Science',
      'confidence': 0.87,
      'needsReview': false,
      'options': [],
    },
    {
      'number': '9',
      'orderIndex': 8,
      'text': 'Explain the causes of the French Revolution.',
      'section': 'Section C',
      'marks': 5,
      'pageNumber': 1,
      'category': 'Social Science',
      'confidence': 0.86,
      'needsReview': false,
      'options': [],
    },
    {
      'number': '1',
      'orderIndex': 9,
      'text': 'Solve for x: 2x + 5 = 15',
      'section': 'Section D',
      'marks': 4,
      'pageNumber': 1,
      'category': 'Maths',
      'confidence': 0.93,
      'needsReview': false,
      'options': [],
    },
  ];

  static const paperTitle = 'Sample Question Bank';
  static const paperSubject = 'General';
  static const paperExamYear = 2024;
  static const paperClassName = 'Class 10';
  static const paperDuration = '3 hours';
  static const paperTotalMarks = 100.0;
  static const paperExamName = 'Annual Examination';

  /// Returns the count of questions per category (for verification).
  static Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final q in questions) {
      final cat = q['category'] as String;
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }
}

/// Converts a dummy data map into a [ParsedQuestion].
ParsedQuestion dummyQuestionFromMap(Map<String, dynamic> m) {
  final optionsRaw = (m['options'] as List? ?? const [])
      .cast<Map<String, dynamic>>();
  return ParsedQuestion(
    number: m['number'] as String,
    orderIndex: m['orderIndex'] as int,
    text: m['text'] as String,
    section: (m['section'] as String?) ?? '',
    marks: (m['marks'] as num?)?.toDouble(),
    options: optionsRaw
        .map((o) => ParsedOption(
              label: (o['label'] as String?) ?? '',
              text: (o['text'] as String?) ?? '',
            ))
        .toList(),
    pageNumber: (m['pageNumber'] as int?) ?? 1,
    confidence: (m['confidence'] as num?)?.toDouble() ?? 0.5,
    warnings: const [],
    rawBlock: '',
  );
}
