import 'package:exam_vault/core/models.dart';
import 'package:exam_vault/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyStudyStat', () {
    test('instantiates and holds daily study values correctly', () {
      final now = DateTime(2026, 11, 15);
      final stat = DailyStudyStat(
        date: now,
        studyMinutes: 45,
        attemptCount: 2,
        accuracyPercentage: 75.0,
      );

      expect(stat.date, now);
      expect(stat.studyMinutes, 45);
      expect(stat.attemptCount, 2);
      expect(stat.accuracyPercentage, 75.0);
    });
  });

  group('AttemptAnswerReview', () {
    test('instantiates review with answer, question and explanation', () {
      final answer = AttemptAnswer(
        id: 1,
        attemptId: 10,
        questionId: 101,
        userAnswer: 'B',
        isCorrect: true,
        timeSpent: 30,
      );

      const question = StoredQuestion(
        id: 101,
        paperId: 1,
        number: '1',
        orderIndex: 0,
        text: 'What is the capital of India?',
        section: 'Section A',
        options: [
          ParsedOption(label: 'A', text: 'Mumbai'),
          ParsedOption(label: 'B', text: 'New Delhi'),
        ],
        pageNumber: 1,
        category: 'Geography',
        difficulty: 'Easy',
        importance: 'High',
        correctOption: 'B',
        isPyq: true,
        confidence: 0.95,
        needsReview: false,
        warnings: [],
        rawBlock: '',
      );

      const explanation = QuestionExplanation(
        id: 1,
        questionId: 101,
        language: 'en',
        explanation: 'New Delhi has been the capital since 1911.',
        source: 'user',
      );

      final review = AttemptAnswerReview(
        answer: answer,
        question: question,
        explanation: explanation,
      );

      expect(review.answer.isCorrect, isTrue);
      expect(review.question.correctOption, 'B');
      expect(review.explanation?.explanation, contains('1911'));
    });
  });
}
