import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../core/extraction/extraction_quality.dart';
import '../core/extraction/raw_document_builder.dart';
import '../core/models.dart';
import 'ocr_extractor.dart';
import 'pdf_text_extractor.dart';

enum ImportStage {
  reading('Reading file'),
  extractingText('Extracting embedded text'),
  runningOcr('Running OCR (scanned PDF)'),
  parsing('Parsing questions'),
  saving('Saving to database'),
  done('Done');

  const ImportStage(this.label);
  final String label;
}

class ImportProgress {
  const ImportProgress({
    required this.stage,
    this.fraction = 0,
    this.detail = '',
  });

  final ImportStage stage;

  /// 0..1 progress within the current stage.
  final double fraction;
  final String detail;

  double get overall {
    switch (stage) {
      case ImportStage.reading:
        return 0.05;
      case ImportStage.extractingText:
        return 0.15 + fraction * 0.25;
      case ImportStage.runningOcr:
        return 0.40 + fraction * 0.35;
      case ImportStage.parsing:
        return 0.80;
      case ImportStage.saving:
        return 0.92;
      case ImportStage.done:
        return 1;
    }
  }
}

class SelectedFile {
  const SelectedFile({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final Uint8List? bytes;

  String get extension => p.extension(name).toLowerCase();

  bool get isSupported => extension == '.pdf' || extension == '.txt';

  bool get isPdf => extension == '.pdf';
}

/// Reads a PDF or text file and turns it into a [RawDocument], choosing the
/// embedded-text path or the OCR path automatically.
class DocumentReader {
  const DocumentReader({
    this.pdfExtractor = const PdfTextExtractorService(),
    this.ocrExtractor = const OcrExtractorService(),
  });

  final PdfTextExtractorService pdfExtractor;
  final OcrExtractorService ocrExtractor;

  Future<RawDocument> read(
    SelectedFile file, {
    void Function(ImportProgress progress)? onProgress,
  }) async {
    if (!file.isSupported) {
      throw const FormatException(
        'Unsupported file type. Please choose a PDF or TXT file.',
      );
    }

    onProgress?.call(const ImportProgress(stage: ImportStage.reading));
    final bytes = await _readBytes(file);
    if (bytes.isEmpty) {
      throw const FormatException('The selected file is empty.');
    }

    if (!file.isPdf) {
      final text = decodeText(bytes);
      final doc = RawDocumentBuilder.fromPlainText(
        fileName: file.name,
        text: text,
        filePath: file.path,
      );
      if (doc.characterCount == 0) {
        throw const FormatException('No readable text was found in this file.');
      }
      return doc;
    }

    onProgress?.call(
      const ImportProgress(stage: ImportStage.extractingText),
    );

    RawDocument doc;
    try {
      doc = pdfExtractor.extract(
        fileName: file.name,
        bytes: bytes,
        filePath: file.path,
      );
    } catch (error) {
      // A damaged or encrypted embedded text layer should not stop us from
      // trying OCR, which only needs the rendered pages.
      doc = RawDocument(
        sourceType: SourceType.pdf,
        method: ExtractionMethod.embeddedText,
        fileName: file.name,
        filePath: file.path,
        pages: const [],
        rawText: '',
      );
    }

    if (ExtractionQuality.needsOcr(doc)) {
      onProgress?.call(
        const ImportProgress(stage: ImportStage.runningOcr),
      );
      doc = await ocrExtractor.extract(
        fileName: file.name,
        bytes: bytes,
        filePath: file.path,
        onProgress: (done, total) {
          onProgress?.call(ImportProgress(
            stage: ImportStage.runningOcr,
            fraction: total == 0 ? 0 : done / total,
            detail: 'Page $done of $total',
          ));
        },
      );
    }

    return doc;
  }

  Future<Uint8List> _readBytes(SelectedFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) return file.bytes!;
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const FormatException('Could not open the selected file.');
    }
    return File(path).readAsBytes();
  }
}

/// Decodes a text file, handling UTF-8 (with or without BOM), UTF-16 LE/BE
/// and falling back to Latin-1 for legacy single-byte encodings.
String decodeText(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes.sublist(2), littleEndian: false);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
  final codeUnits = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    codeUnits.add(littleEndian
        ? bytes[i] | (bytes[i + 1] << 8)
        : (bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(codeUnits);
}
