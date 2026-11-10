import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:exam_vault/core/extraction/raw_document_builder.dart';
import 'package:exam_vault/core/parsing/question_parser.dart';

void main() {
  test('parses the sample paper end to end', () {
    final text = File('sample_exam_paper.txt').readAsStringSync();
    final document = RawDocumentBuilder.fromPlainText(
      fileName: 'sample_exam_paper.txt',
      text: text,
    );

    final result = const QuestionParser().parse(document);

    expect(result.questions.length, 6);
    expect(result.metadata.subject, 'Science');
    expect(result.metadata.examYear, 2024);
    expect(result.metadata.className, 'Class 10');
    expect(result.metadata.totalMarks, 40);

    final q1 = result.questions.firstWhere((q) => q.number == '1');
    expect(q1.marks, 2);
    expect(q1.options.length, 4);
    expect(q1.options.first.label, 'A');

    final q2 = result.questions.firstWhere((q) => q.number == '2');
    expect(q2.options.length, 4);
    expect(q2.text, contains('chemical symbol'));

    final q3 = result.questions.firstWhere((q) => q.number == '3');
    expect(q3.text, contains('photosynthesis'));
    expect(q3.section.toUpperCase(), contains('SECTION A'));

    final q4 = result.questions.firstWhere((q) => q.number == '4');
    expect(q4.section.toUpperCase(), contains('SECTION B'));

    final q5 = result.questions.firstWhere((q) => q.number == '5');
    expect(q5.options.length, 4);

    final q6 = result.questions.firstWhere((q) => q.number == '6');
    expect(q6.marks, 1);
    expect(q6.text, contains('largest ocean'));
  });
}
