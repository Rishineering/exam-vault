import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exam_vault/core/models.dart';
import 'package:exam_vault/data/models.dart';
import 'package:exam_vault/ui/question_table.dart';

void main() {
  testWidgets('question table renders a row and reports taps', (tester) async {
    final question = StoredQuestion(
      id: 1,
      paperId: 1,
      number: '1',
      orderIndex: 0,
      text: 'What is the capital of India?',
      section: 'Section A',
      marks: 2,
      options: const [
        ParsedOption(label: 'A', text: 'Delhi'),
        ParsedOption(label: 'B', text: 'Mumbai'),
      ],
      pageNumber: 1,
      category: '',
      difficulty: 'Medium',
      importance: 'Medium',
      isPyq: false,
      examYear: null,
      examName: null,
      confidence: 0.92,
      needsReview: false,
      warnings: const [],
      rawBlock: '',
    );

    StoredQuestion? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionTable(
            questions: [question],
            onTap: (value) => tapped = value,
          ),
        ),
      ),
    );

    expect(find.text('What is the capital of India?'), findsOneWidget);
    expect(find.text('Section A'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);

    await tester.tap(find.text('What is the capital of India?'));
    await tester.pump();

    expect(tapped?.id, 1);
  });

  testWidgets('question table shows an empty message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuestionTable(
            questions: [],
            onTap: _noop,
            emptyMessage: 'Nothing here',
          ),
        ),
      ),
    );

    expect(find.text('Nothing here'), findsOneWidget);
  });
}

void _noop(StoredQuestion question) {}
