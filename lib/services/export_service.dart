import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';

/// Builds a spreadsheet-friendly CSV (one row per question) and shares it.
class ExportService {
  const ExportService();

  static const List<String> _headers = [
    'Paper',
    'Exam',
    'Subject',
    'Year',
    'Class',
    'Duration',
    'Total Marks',
    'Section',
    'Q.No',
    'Question',
    'Marks',
    'Options',
    'Page',
    'Confidence %',
    'Needs Review',
    'Warnings',
  ];

  String buildCsv(PaperDetail detail) {
    final paper = detail.paper;
    final metadata = paper.metadata;
    final buffer = StringBuffer();

    buffer.writeln(_row(_headers));
    for (final question in detail.questions) {
      buffer.writeln(_row([
        paper.title,
        metadata.examName ?? '',
        metadata.subject ?? '',
        metadata.examYear?.toString() ?? '',
        metadata.className ?? '',
        metadata.duration ?? '',
        metadata.totalMarks?.toString() ?? '',
        question.section,
        question.number,
        question.text,
        question.marks?.toString() ?? '',
        question.options.map((o) => '${o.label}) ${o.text}').join(' | '),
        question.pageNumber.toString(),
        (question.confidence * 100).round().toString(),
        question.needsReview ? 'Yes' : 'No',
        question.warnings.join(' | '),
      ]));
    }
    return buffer.toString();
  }

  Future<File> writeCsv(PaperDetail detail) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, '${_safeName(detail.paper.title)}.csv'));
    // A UTF-8 BOM makes Excel open non-ASCII text correctly.
    await file.writeAsString('\uFEFF${buildCsv(detail)}', encoding: utf8);
    return file;
  }

  Future<ShareResult> shareCsv(PaperDetail detail) async {
    final file = await writeCsv(detail);
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '${detail.paper.title} - extracted questions',
        text: '${detail.questions.length} questions extracted by SetYourRank.',
      ),
    );
  }

  String _safeName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'exam_questions';
    if (cleaned.length <= 60) return cleaned;
    return cleaned.substring(0, 60).trim();
  }

  String _row(List<String> cells) => cells.map(_escape).join(',');

  String _escape(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
