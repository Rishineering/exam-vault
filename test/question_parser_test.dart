import 'package:flutter_test/flutter_test.dart';

import 'package:exam_vault/core/extraction/extraction_quality.dart';
import 'package:exam_vault/core/extraction/raw_document_builder.dart';
import 'package:exam_vault/core/models.dart';
import 'package:exam_vault/core/parsing/patterns.dart';
import 'package:exam_vault/core/parsing/question_parser.dart';

RawDocument textDoc(String text) => RawDocumentBuilder.fromPlainText(
      fileName: 'paper.txt',
      text: text,
    );

RawDocument pdfDoc(List<PageLayout> pages) => RawDocumentBuilder.fromPdfLines(
      fileName: 'paper.pdf',
      filePath: null,
      method: ExtractionMethod.embeddedText,
      pages: pages,
    );

LayoutLine line(
  int page,
  String text, {
  double x = 50,
  double y = 100,
  double w = 300,
}) =>
    LayoutLine(
      pageNumber: page,
      text: text,
      left: x,
      top: y,
      width: w,
      height: 12,
    );

void main() {
  const parser = QuestionParser();

  group('metadata + segmentation', () {
    test('parses a full paper with sections, marks and options', () {
      final result = parser.parse(textDoc(r'''
BOARD OF SECONDARY EDUCATION
SAMPLE QUESTION PAPER 2023
Class: X
Subject: Mathematics
Time Allowed: 3 hours
Maximum Marks: 80
General Instructions:
1. All questions are compulsory.
2. The question paper consists of 4 sections.
SECTION A
1. The value of 2 + 2 is: [1]
(A) 3
(B) 4
(C) 5
(D) 6
2. Define photosynthesis. (2 marks)
SECTION B
11. Explain the water cycle with a diagram. (5 marks)
12. Solve for x: 2x + 3 = 11. [3]
'''));

      expect(result.metadata.subject, 'Mathematics');
      expect(result.metadata.examYear, 2023);
      expect(result.metadata.totalMarks, 80);
      expect(result.metadata.duration, '3 hours');
      expect(result.metadata.className, 'Class X');
      expect(result.metadata.title, contains('Sample Question Paper'));
      expect(result.metadata.examName, contains('Board'));

      expect(result.questions, hasLength(4));
      expect(
        result.questions.map((q) => q.number).toList(),
        ['1', '2', '11', '12'],
      );

      final q1 = result.questions[0];
      expect(q1.section, 'SECTION A');
      expect(q1.marks, 1);
      expect(q1.options, hasLength(4));
      expect(q1.options.map((o) => o.label).toList(), ['A', 'B', 'C', 'D']);
      expect(q1.text, contains('2 + 2'));
      expect(q1.text, isNot(contains('(A)')));

      final q2 = result.questions[1];
      expect(q2.marks, 2);
      expect(q2.text, contains('photosynthesis'));
      expect(q2.text, isNot(contains('2 marks')));

      final q11 = result.questions[2];
      expect(q11.section, 'SECTION B');
      expect(q11.marks, 5);

      final q12 = result.questions[3];
      expect(q12.marks, 3);
      expect(q12.text, contains('2x + 3 = 11'));
    });

    test('recognises common question-number formats', () {
      final result = parser.parse(textDoc(r'''
Q.1 Define force.
Q.2 State Newton's first law.
Question No. 3: What is inertia?
4) Give an example of inertia.
5 - Name the unit of force.
'''));

      expect(
        result.questions.map((q) => q.number).toList(),
        ['1', '2', '3', '4', '5'],
      );
    });

    test('a four-digit year is never treated as a question', () {
      expect(matchQuestionStart('2023.'), isNull);
      expect(matchQuestionStart('2023'), isNull);
    });
  });

  group('marks', () {
    test('extracts and removes marks in several formats', () {
      final result = parser.parse(textDoc(r'''
1. Define A. (2)
2. Define B. [3]
3. Define C. 4 Marks
4. Define D. Marks: 5
'''));

      expect(
        result.questions.map((q) => q.marks).toList(),
        [2, 3, 4, 5],
      );
      expect(
        result.questions.map((q) => q.text).toList(),
        ['Define A.', 'Define B.', 'Define C.', 'Define D.'],
      );
    });
  });

  group('options', () {
    test('separates uppercase MCQ options from the stem', () {
      final result = parser.parse(textDoc(r'''
1. Which of the following is a prime number? [1]
(A) 4
(B) 6
(C) 7
(D) 9
'''));

      final question = result.questions.single;
      expect(question.options, hasLength(4));
      expect(question.text, contains('prime number'));
      expect(question.text, isNot(contains('(A)')));
      expect(question.marks, 1);
    });

    test('numeric MCQ options are not mistaken for new questions', () {
      final result = parser.parse(textDoc(r'''
1. Choose the correct option: [1]
1) 2
2) 3
3) 4
4) 5
2. What is 2 + 2? [1]
(A) 3
(B) 4
(C) 5
(D) 6
'''));

      expect(result.questions, hasLength(2));
      final q1 = result.questions[0];
      expect(q1.options, hasLength(4));
      expect(q1.options.map((o) => o.label).toList(), ['1', '2', '3', '4']);
      expect(q1.text, contains('Choose the correct option'));

      final q2 = result.questions[1];
      expect(q2.number, '2');
      expect(q2.options, hasLength(4));
    });

    test('lower-case sub-parts stay in the question text', () {
      final result = parser.parse(textDoc(r'''
1. Answer the following:
(a) Define force.
(b) State Newton's first law.
(c) Give an example.
2. Define energy.
'''));

      expect(result.questions, hasLength(2));
      final q1 = result.questions[0];
      expect(q1.options, isEmpty);
      expect(q1.text, contains('(a) Define force.'));
      expect(q1.text, contains('(b) State Newton'));
      expect(q1.text, contains('\n'));

      expect(result.questions[1].number, '2');
      expect(result.questions[1].text, 'Define energy.');
    });

    test('inline options are split correctly', () {
      final result = parser.parse(textDoc(
        '1. Which of the following is correct? (A) 1 (B) 2 (C) 3 (D) 4',
      ));

      final question = result.questions.single;
      expect(question.options, hasLength(4));
      expect(question.text, 'Which of the following is correct?');
    });
  });

  group('layout', () {
    test('reads a two-column page column by column', () {
      final doc = pdfDoc([
        PageLayout(
          pageNumber: 1,
          width: 600,
          height: 800,
          lines: [
            line(1, 'SAMPLE PAPER 2023', x: 50, y: 20, w: 500),
            line(1, '1. What is force?', x: 50, y: 100, w: 250),
            line(1, 'Explain with an example.', x: 50, y: 120, w: 250),
            line(1, '2. Define energy.', x: 50, y: 160, w: 250),
            line(1, '3. What is power?', x: 320, y: 100, w: 250),
            line(1, 'Give its unit.', x: 320, y: 120, w: 250),
            line(1, "4. State Ohm's law.", x: 320, y: 160, w: 250),
          ],
        ),
      ]);

      final result = parser.parse(doc);
      expect(
        result.questions.map((q) => q.number).toList(),
        ['1', '2', '3', '4'],
      );
      expect(result.questions[0].text, contains('Explain with an example'));
      expect(result.questions[2].text, contains('Give its unit'));
    });

    test('removes repeated headers and page numbers', () {
      final pages = <PageLayout>[];
      for (var p = 1; p <= 3; p++) {
        final base = (p - 1) * 2 + 1;
        pages.add(PageLayout(
          pageNumber: p,
          width: 600,
          height: 800,
          lines: [
            line(p, 'BOARD EXAM 2023', x: 50, y: 10, w: 500),
            line(p, '$base. Question number $base?', x: 50, y: 100),
            line(p, '${base + 1}. Question number ${base + 1}?',
                x: 50, y: 140),
            line(p, 'Page $p of 3', x: 250, y: 780, w: 100),
          ],
        ));
      }

      final result = parser.parse(pdfDoc(pages));
      expect(result.questions, hasLength(6));
      expect(
        result.questions.map((q) => q.number).toList(),
        ['1', '2', '3', '4', '5', '6'],
      );
      expect(
        result.questions.every((q) => !q.text.contains('BOARD EXAM')),
        isTrue,
      );
      expect(
        result.questions.every((q) => !q.text.contains('Page ')),
        isTrue,
      );
    });
  });

  group('fallback and robustness', () {
    test('splits unnumbered text into reviewable paragraphs', () {
      final result = parser.parse(textDoc(r'''
Read the following passage carefully.
The sun rises in the east.
It sets in the west.
This movement is caused by the rotation of the earth.
What is the main idea of the passage?
Why does the sun appear to move across the sky?
'''));

      expect(result.questions.length, greaterThanOrEqualTo(2));
      expect(
        result.questions.every((q) => q.confidence < 0.6),
        isTrue,
      );
      expect(
        result.warnings.any((w) => w.contains('No reliable question numbering')),
        isTrue,
      );
    });

    test('handles an empty document without throwing', () {
      final doc = RawDocument(
        sourceType: SourceType.txt,
        method: ExtractionMethod.plainText,
        fileName: 'empty.txt',
        pages: const [],
        rawText: '',
      );

      final result = parser.parse(doc);
      expect(result.questions, isEmpty);
      expect(result.warnings, isNotEmpty);
    });

    test('section header detection rejects prose', () {
      expect(matchSectionHeader('SECTION A'), 'SECTION A');
      expect(matchSectionHeader('PART - II'), isNotNull);
      expect(matchSectionHeader('Part of the question is missing'), isNull);
    });
  });

  group('OCR decision', () {
    test('requests OCR when a PDF has almost no text', () {
      final sparse = pdfDoc([
        PageLayout(
          pageNumber: 1,
          width: 600,
          height: 800,
          lines: [line(1, '1', w: 10)],
        ),
      ]);
      expect(ExtractionQuality.needsOcr(sparse), isTrue);
    });

    test('does not request OCR for a normal text PDF', () {
      final rich = pdfDoc([
        PageLayout(
          pageNumber: 1,
          width: 600,
          height: 800,
          lines: [
            line(1, '1. Explain the process of photosynthesis in plants.', w: 500),
            line(1, '2. State the laws of motion with examples.', w: 500),
            line(1, '3. Solve the following quadratic equation.', w: 500),
          ],
        ),
      ]);
      expect(ExtractionQuality.needsOcr(rich), isFalse);
    });
  });
}
