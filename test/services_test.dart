import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:exam_vault/core/models.dart';
import 'package:exam_vault/data/models.dart';
import 'package:exam_vault/services/document_reader.dart';
import 'package:exam_vault/services/export_service.dart';

void main() {
  group('decodeText', () {
    test('decodes plain UTF-8', () {
      expect(decodeText(Uint8List.fromList(utf8.encode('Hello'))), 'Hello');
    });

    test('decodes UTF-8 with a BOM', () {
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode('héllo')];
      expect(decodeText(Uint8List.fromList(bytes)), 'héllo');
    });

    test('decodes UTF-16 little-endian with a BOM', () {
      final bytes = <int>[0xFF, 0xFE, 0x68, 0x00, 0x69, 0x00];
      expect(decodeText(Uint8List.fromList(bytes)), 'hi');
    });

    test('decodes UTF-16 big-endian with a BOM', () {
      final bytes = <int>[0xFE, 0xFF, 0x00, 0x68, 0x00, 0x69];
      expect(decodeText(Uint8List.fromList(bytes)), 'hi');
    });

    test('falls back to Latin-1 for invalid UTF-8', () {
      expect(decodeText(Uint8List.fromList([0xE9])), 'é');
    });
  });

  test('buildCsv escapes commas, quotes and newlines', () {
    final paper = PaperRecord(
      id: 1,
      title: 'Sample, "Paper"',
      fileName: 'sample.pdf',
      sourceType: SourceType.pdf,
      method: ExtractionMethod.embeddedText,
      pageCount: 2,
      questionCount: 1,
      reviewCount: 0,
      averageConfidence: 0.9,
      metadata: const PaperMetadata(subject: 'Maths', examYear: 2024),
      warnings: const [],
      createdAt: DateTime(2024, 1, 1),
    );

    final question = StoredQuestion(
      id: 1,
      paperId: 1,
      number: '1',
      orderIndex: 0,
      text: 'What is 1,000 + 2?\nExplain.',
      section: 'A',
      marks: 2,
      options: const [
        ParsedOption(label: 'A', text: '1002'),
        ParsedOption(label: 'B', text: '1003'),
      ],
      pageNumber: 1,
      category: '',
      confidence: 0.9,
      needsReview: false,
      warnings: const [],
      rawBlock: '',
    );

    final csv = const ExportService()
        .buildCsv(PaperDetail(paper: paper, questions: [question]));

    expect(csv, contains('"Sample, ""Paper"""'));
    expect(csv, contains('"What is 1,000 + 2?\nExplain."'));
    expect(csv, contains('A) 1002 | B) 1003'));
    expect(csv, contains('Maths'));
  });
}
