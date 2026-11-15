import 'package:exam_vault/core/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppText', () {
    test('returns English labels for the en profile', () {
      const text = AppText('en');
      expect(text.isHindi, isFalse);
      expect(text.bookmarks, 'Bookmarks');
      expect(text.revisionQueue, 'Revision Queue');
      expect(text.answerExplanations, 'Answer Explanations');
      expect(text.difficultyLabel('Easy'), 'Easy');
    });

    test('returns Hindi labels for the hi profile', () {
      const text = AppText('hi');
      expect(text.isHindi, isTrue);
      expect(text.bookmarks, 'बुकमार्क');
      expect(text.revisionQueue, 'रिवीज़न कतार');
      expect(text.answerExplanations, 'उत्तर व्याख्या');
      expect(text.difficultyLabel('Medium'), 'मध्यम');
    });

    test('bilingual profile uses the Hindi labels', () {
      const text = AppText('bilingual');
      expect(text.isHindi, isTrue);
      expect(text.home, 'होम');
    });

    test('plural helpers include the count', () {
      const text = AppText('en');
      expect(text.pyqCount(1), '1 PYQ question');
      expect(text.pyqCount(4), '4 PYQ questions');
      expect(text.revisionInterval(1), 'Interval: 1 day');
      expect(text.revisionInterval(3), 'Interval: 3 days');
    });
  });
}
